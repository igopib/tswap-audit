// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TSwapPool} from "../../src/PoolFactory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TSwapPoolTest is Test {
    TSwapPool pool;
    ERC20Mock poolToken;
    ERC20Mock weth;

    address liquidityProvider = makeAddr("liquidityProvider");
    address user = makeAddr("user");

    function setUp() public {
        poolToken = new ERC20Mock();
        weth = new ERC20Mock();
        pool = new TSwapPool(
            address(poolToken),
            address(weth),
            "LTokenA",
            "LA"
        );

        weth.mint(liquidityProvider, 200e18);
        poolToken.mint(liquidityProvider, 200e18);

        weth.mint(user, 10e18);
        poolToken.mint(user, 10e18);
    }

    function testDeposit() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.balanceOf(liquidityProvider), 100e18);
        assertEq(weth.balanceOf(liquidityProvider), 100e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 100e18);

        assertEq(weth.balanceOf(address(pool)), 100e18);
        assertEq(poolToken.balanceOf(address(pool)), 100e18);
    }

    function testDepositSwap() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        poolToken.approve(address(pool), 10e18);
        // After we swap, there will be ~110 tokenA, and ~91 WETH
        // 100 * 100 = 10,000
        // 110 * ~91 = 10,000
        uint256 expected = 9e18;

        pool.swapExactInput(
            poolToken,
            10e18,
            weth,
            expected,
            uint64(block.timestamp)
        );
        assert(weth.balanceOf(user) >= expected);
    }

    function testWithdraw() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.totalSupply(), 0);
        assertEq(weth.balanceOf(liquidityProvider), 200e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 200e18);
    }

    function testCollectFees() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        uint256 expected = 9e18;
        poolToken.approve(address(pool), 10e18);
        pool.swapExactInput(
            poolToken,
            10e18,
            weth,
            expected,
            uint64(block.timestamp)
        );
        vm.stopPrank();

        vm.startPrank(liquidityProvider);
        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 90e18, 100e18, uint64(block.timestamp));
        assertEq(pool.totalSupply(), 0);
        assert(
            weth.balanceOf(liquidityProvider) +
                poolToken.balanceOf(liquidityProvider) >
                400e18
        );
    }

    function testBadFeeCalculations() public {
        uint256 initialLiquidity = 100e18;
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), initialLiquidity);
        poolToken.approve(address(pool), initialLiquidity);

        pool.deposit(
            initialLiquidity,
            0,
            initialLiquidity,
            uint64(block.timestamp)
        );
        vm.stopPrank();

        address depositor = makeAddr("depositor");
        uint256 intitalTokenValue = 12e18;
        poolToken.mint(depositor, intitalTokenValue);

        vm.startPrank(depositor);
        poolToken.approve(address(pool), type(uint256).max);
        console.log(poolToken.balanceOf(depositor));
        pool.swapExactOutput(poolToken, weth, 1 ether, uint64(block.timestamp));

        assertLt(poolToken.balanceOf(depositor), 1 ether);
        vm.stopPrank();

        vm.startPrank(liquidityProvider);
        pool.withdraw(
            pool.balanceOf(liquidityProvider),
            1,
            1,
            uint64(block.timestamp)
        );

        assertEq(weth.balanceOf(address(pool)), 0);
        assertEq(pool.balanceOf(address(pool)), 0);
    }

    function testProblemInSellPoolToken() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        uint256 poolTknSellAmount = 50000000;
        vm.startPrank(user);
        poolToken.approve(address(pool), type(uint256).max);
        uint256 wethBefore = weth.balanceOf(user);
        assertEq(poolTknSellAmount, pool.sellPoolTokens(poolTknSellAmount));
        uint256 wethAfter = weth.balanceOf(user);

        console.log(wethBefore, wethAfter);
    }

    function testProblemFixingSellPoolToken() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        uint256 poolTknSellAmount = 50000000;
        vm.startPrank(user);
        poolToken.approve(address(pool), type(uint256).max);
        uint256 wethBefore = weth.balanceOf(user);
        uint256 tokenSent = pool.sellPoolTokens(poolTknSellAmount);
        assertEq(poolTknSellAmount, tokenSent);
        uint256 wethAfter = weth.balanceOf(user);

        console.log(wethBefore, wethAfter);
    }

    function testInvariantBreakUnit() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);

        uint256 outputWeth = 1e17;
        poolToken.mint(user, 100e18);
        int256 startingY = int256(weth.balanceOf(address(pool)));
        int256 expectedDeltaY = int256(-1) * int256(outputWeth);

        vm.startPrank(user);
        poolToken.approve(address(pool), type(uint64).max);
        pool.swapExactOutput(
            poolToken,
            weth,
            outputWeth,
            uint64(block.timestamp)
        );
        pool.swapExactOutput(
            poolToken,
            weth,
            outputWeth,
            uint64(block.timestamp)
        );
        pool.swapExactOutput(
            poolToken,
            weth,
            outputWeth,
            uint64(block.timestamp)
        );
        pool.swapExactOutput(
            poolToken,
            weth,
            outputWeth,
            uint64(block.timestamp)
        );
        pool.swapExactOutput(
            poolToken,
            weth,
            outputWeth,
            uint64(block.timestamp)
        );
        pool.swapExactOutput(
            poolToken,
            weth,
            outputWeth,
            uint64(block.timestamp)
        );
        pool.swapExactOutput(
            poolToken,
            weth,
            outputWeth,
            uint64(block.timestamp)
        );
        pool.swapExactOutput(
            poolToken,
            weth,
            outputWeth,
            uint64(block.timestamp)
        );
        pool.swapExactOutput(
            poolToken,
            weth,
            outputWeth,
            uint64(block.timestamp)
        );
        pool.swapExactOutput(
            poolToken,
            weth,
            outputWeth,
            uint64(block.timestamp)
        );
        pool.swapExactOutput(
            poolToken,
            weth,
            outputWeth,
            uint64(block.timestamp)
        );
        vm.stopPrank();

        uint256 endingY = weth.balanceOf(address(pool));
        int256 actualDeltaY = int256(endingY) - int256(startingY);
        assertEq(actualDeltaY, expectedDeltaY);
    }
}
