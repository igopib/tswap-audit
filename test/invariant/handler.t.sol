// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {TSwapPool} from "../../src/TSwapPool.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract Handler is Test {
    TSwapPool pool;
    ERC20Mock weth;
    ERC20Mock poolToken;

    address liquidityProvider = makeAddr("liquidityProvider");
    address swapper = makeAddr("swapper");

    int256 public startingX; //starting erc20
    int256 public startingY; //starting weth
    int256 public expectedDeltaX;
    int256 public expectedDeltaY;
    int256 public actualDeltaX;
    int256 public actualDeltaY;

    constructor(TSwapPool _pool) {
        pool = _pool;
        weth = ERC20Mock(address(_pool.getWeth()));
        poolToken = ERC20Mock(address(_pool.getPoolToken()));
    }

    function swapPoolTokenForWethBasedOnOutputWeth(uint256 outputWeth) public {
        uint256 minimumWeth = pool.getMinimumWethDepositAmount();
        outputWeth = bound(
            outputWeth,
            minimumWeth,
            weth.balanceOf(address(pool))
        );
        if (outputWeth >= weth.balanceOf(address(pool))) {
            return;
        }

        // ∆x = (β/(1-β)) * x || x * y = k
        uint256 poolTokenAmount = pool.getInputAmountBasedOnOutput(
            outputWeth,
            poolToken.balanceOf(address(pool)),
            weth.balanceOf(address(pool))
        );
        if (poolTokenAmount > type(uint64).max) {
            return;
        }

        startingY = int256(weth.balanceOf(address(pool)));
        startingX = int256(poolToken.balanceOf(address(pool)));
        expectedDeltaY = int256(-1) * int256(outputWeth);
        expectedDeltaX = int256(poolTokenAmount);
        if (poolToken.balanceOf(swapper) < poolTokenAmount) {
            poolToken.mint(
                swapper,
                poolTokenAmount - poolToken.balanceOf(swapper) + 1
            );
        }

        vm.startPrank(swapper);
        poolToken.approve(address(pool), type(uint64).max);
        pool.swapExactOutput(
            poolToken,
            weth,
            outputWeth,
            uint64(block.timestamp)
        );
        vm.stopPrank();

        //calculate deltas here
        uint256 endingX = poolToken.balanceOf(address(pool));
        uint256 endingY = weth.balanceOf(address(pool));

        actualDeltaX = int256(endingX) - int256(startingX);
        actualDeltaY = int256(endingY) - int256(startingY);
    }

    // deposit, swapExactOutput
    function deposit(uint256 wethAmount) public {
        // restricting wethAmount to be a certain amount to prevent overflow/underflows
        uint256 minimumWeth = pool.getMinimumWethDepositAmount();
        wethAmount = bound(wethAmount, minimumWeth, type(uint64).max);

        startingY = int256(weth.balanceOf(address(pool)));
        startingX = int256(poolToken.balanceOf(address(pool)));
        expectedDeltaY = int256(wethAmount);
        expectedDeltaX = int256(
            pool.getPoolTokensToDepositBasedOnWeth(wethAmount)
        );

        //giving lp tokens and approval
        vm.startPrank(liquidityProvider);
        weth.mint(liquidityProvider, uint256(wethAmount));
        poolToken.mint(liquidityProvider, uint256(expectedDeltaX));
        weth.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);
        //deposit
        pool.deposit(
            wethAmount,
            0,
            uint256(expectedDeltaX),
            uint64(block.timestamp)
        );
        vm.stopPrank();

        //actual deltas
        uint256 endingX = poolToken.balanceOf(address(pool));
        uint256 endingY = weth.balanceOf(address(pool));

        actualDeltaX = int256(endingX) - int256(startingX);
        actualDeltaY = int256(endingY) - int256(startingY);
    }
}
