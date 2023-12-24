---
title: TSwap Audit Report
author: Gopinho
date: Dec 24, 2023
header-includes:
  - \usepackage{titling}
  - \usepackage{graphicx}
---

\begin{titlepage}
\centering
\begin{figure}[h]
\centering
\includegraphics[width=0.5\textwidth]{logo.pdf}
\end{figure}
\vspace{2cm}
{\Huge\bfseries PuppyRaffle Audit Report\par}
\vspace{1cm}
{\Large Version 1.0\par}
\vspace{2cm}
{\Large\itshape profileos.vercel.app\par}
\vfill
{\large \today\par}
\end{titlepage}

\maketitle

<!-- Your report starts here! -->

Prepared by: [Gurpreet](https://profileos.vercel.app)
Lead Researcher:

- Gurpreet

# Table of Contents

- [Table of Contents](#table-of-contents)
- [Protocol Summary](#protocol-summary)
- [Disclaimer](#disclaimer)
- [Risk Classification](#risk-classification)
- [Audit Details](#audit-details)
  - [Scope](#scope)
  - [Roles](#roles)
- [Executive Summary](#executive-summary)
  - [Issues found](#issues-found)
- [Findings](#findings)
  - [High](#high)
    - [\[H-1\] Function `PuppyRaffle::refund` is vulnerable to reenteracy attacks.](#h-1-function-puppyrafflerefund-is-vulnerable-to-reenteracy-attacks)
    - [\[H-2\] Function `PuppyRaffle::selectWinner` uses insecure ways of generating random winner for `winnerIndex`.](#h-2-function-puppyraffleselectwinner-uses-insecure-ways-of-generating-random-winner-for-winnerindex)
    - [\[H-3\] Overflow and Underflow](#h-3-overflow-and-underflow)
    - [\[H-4\] `PuppyRaffle::selectWinner` uses very unsafe require statement, which can lead to not being able to withdraw the fee.](#h-4-puppyraffleselectwinner-uses-very-unsafe-require-statement-which-can-lead-to-not-being-able-to-withdraw-the-fee)
  - [Medium](#medium)
    - [\[M-1\] Function `PuppyRaffle::enterRaffle` is exposed to DOS(Denial of service) attacks, looping through unchecked players array.](#m-1-function-puppyraffleenterraffle-is-exposed-to-dosdenial-of-service-attacks-looping-through-unchecked-players-array)
  - [Informational](#informational)
    - [\[I-1\] Solidity pragma should be specific, not wide](#i-1-solidity-pragma-should-be-specific-not-wide)
    - [\[I-2\] Using outdated versions of Solidity is not recommended.](#i-2-using-outdated-versions-of-solidity-is-not-recommended)
    - [\[I-3\] \_isActivePlayer is never used and should be removed](#i-3-_isactiveplayer-is-never-used-and-should-be-removed)
    - [\[I-4\] Zero address may be erroneously considered an active player](#i-4-zero-address-may-be-erroneously-considered-an-active-player)
  - [Gas](#gas)
    - [\[G-1\] Unchanged variables should be constant or immutable](#g-1-unchanged-variables-should-be-constant-or-immutable)

# Protocol Summary

TSwap contracts allow users to provide liquidity for certain erc20 using weth as the pair.

# Disclaimer

The Gurpreet(gopinho) team makes all effort to find as many vulnerabilities in the code in the given time period, but holds no responsibilities for the findings provided in this document. A security audit by the team is not an endorsement of the underlying business or product. The audit was time-boxed and the review of the code was solely on the security aspects of the Solidity implementation of the contracts.

# Risk Classification

|            |        | Impact |        |     |
| ---------- | ------ | ------ | ------ | --- |
|            |        | High   | Medium | Low |
|            | High   | H      | H/M    | M   |
| Likelihood | Medium | H/M    | M      | M/L |
|            | Low    | M      | M/L    | L   |

We use the [CodeHawks](https://docs.codehawks.com/hawks-auditors/how-to-evaluate-a-finding-severity) severity matrix to determine severity. See the documentation for more details.

# Audit Details

**The findings in this documents corrosponds to the following commit hash**

```
f426f57731208727addc20adb72cb7f5bf29dc03
```

## Scope

```
src/PoolFactory.sol
src/TSwapPool.sol
```

## Roles

- Owner: Deployer of the contract, has power to change the address of to which fee is sent using `changeFeeAddress` function.

- Player: Participant of the protocol, they enter the raffle through `enterRaffle` function and has ability to get a refund using `refund` function.

# Executive Summary

Manual review including foundry fuzz tests were expended on this contract.

## Issues found

| Severity | Number of issues |
| -------- | ---------------- |
| High     | 4                |
| Medium   | 1                |
| Info     | 2                |
| Gas      | 3                |
| Total    | 10               |

# Findings

## High

### [H-1] Incorrect fee calculation in `TSwapPool::getInputAmountBasedOnOutput` method, fee calculation ends up being 93.5% instead of 0.3%.

**Description:** The function `getInputAmountBasedOnOutput` is inded to calculate the amount of tokens a user has to deposit given an amount of output tokens. However the function miscalculates while calculating the fee resulting in lost fees. While calculating it used 10_000 instead of 1_000.

**Impact:** Potentially take more tokens from user than intended.

**Proof of Concept:**

**Recommended Mitigation:**

### [H-2] Lack of slippage protection in `TSwapPool::swapExactOutput`, causes users to to potentially lose tokens.

**Description:** The swapExactOutput function does not include any sort of slippage protection. This function is similar to what is done in TSwapPool::swapExactInput, where the function specifies a minOutputAmount, the swapExactOutput function should specify a maxInputAmount.

**Impact:** If market conditions change before the transaciton processes, the user could get a much worse swap.

**Recommended Mitigation:** We should include a maxInputAmount so the user only has to spend up to a specific amount, and can predict how much they will spend on the protocol.

```diff
    function swapExactOutput(
        IERC20 inputToken,
+       uint256 maxInputAmount,
.
.
.
        inputAmount = getInputAmountBasedOnOutput(outputAmount, inputReserves, outputReserves);
+       if(inputAmount > maxInputAmount){
+           revert();
+       }
        _swap(inputToken, inputAmount, outputToken, outputAmount);
```

### [H-3] `TSwapPool::sellPoolTokens` mismatches input and output tokens causing users to receive the incorrect amount of tokens

**Description:** The `sellPoolTokens` function is intended to allow users to easily sell pool tokens and receive WETH in exchange. Users indicate how many pool tokens they're willing to sell in the `poolTokenAmount` parameter. However, the function currently miscalculaes the swapped amount.

This is due to the fact that the `swapExactOutput` function is called, whereas the `swapExactInput` function is the one that should be called. Because users specify the exact amount of input tokens, not output.

**Impact:** Users will swap the wrong amount of tokens, which is a severe disruption of protcol functionality.

**Recommended Mitigation:**

Consider changing the implementation to use `swapExactInput` instead of `swapExactOutput`. Note that this would also require changing the `sellPoolTokens` function to accept a new parameter (ie `minWethToReceive` to be passed to `swapExactInput`)

```diff
    function sellPoolTokens(
        uint256 poolTokenAmount,
+       uint256 minWethToReceive,
        ) external returns (uint256 wethAmount) {
-        return swapExactOutput(i_poolToken, i_wethToken, poolTokenAmount, uint64(block.timestamp));
+        return swapExactInput(i_poolToken, poolTokenAmount, i_wethToken, minWethToReceive, uint64(block.timestamp));
    }
```

Additionally, it might be wise to add a deadline to the function, as there is currently no deadline.

### [H-4] In `TSwapPool::_swap` the extra tokens given to users after every `swapCount` breaks the protocol invariant of `x * y = k`

**Description:** The protocol follows a strict invariant of `x * y = k`. Where:

- `x`: The balance of the pool token
- `y`: The balance of WETH
- `k`: The constant product of the two balances

This means, that whenever the balances change in the protocol, the ratio between the two amounts should remain constant, hence the `k`. However, this is broken due to the extra incentive in the `_swap` function. Meaning that over time the protocol funds will be drained.

The follow block of code is responsible for the issue.

```javascript
swap_count++
if (swap_count >= SWAP_COUNT_MAX) {
  swap_count = 0
  outputToken.safeTransfer(msg.sender, 1_000_000_000_000_000_000)
}
```

**Impact:** A user could maliciously drain the protocol of funds by doing a lot of swaps and collecting the extra incentive given out by the protocol.

Most simply put, the protocol's core invariant is broken.

**Proof of Concept:**

1. A user swaps 10 times, and collects the extra incentive of `1_000_000_000_000_000_000` tokens
2. That user continues to swap untill all the protocol funds are drained

<details>
<summary>Proof Of Code</summary>

Place the following into `TSwapPool.t.sol`.

```javascript

    function testInvariantBroken() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        uint256 outputWeth = 1e17;

        vm.startPrank(user);
        poolToken.approve(address(pool), type(uint256).max);
        poolToken.mint(user, 100e18);
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));

        int256 startingY = int256(weth.balanceOf(address(pool)));
        int256 expectedDeltaY = int256(-1) * int256(outputWeth);

        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        vm.stopPrank();

        uint256 endingY = weth.balanceOf(address(pool));
        int256 actualDeltaY = int256(endingY) - int256(startingY);
        assertEq(actualDeltaY, expectedDeltaY);
    }
```

</details>

**Recommended Mitigation:** Remove the extra incentive mechanism. If you want to keep this in, we should account for the change in the x \* y = k protocol invariant. Or, we should set aside tokens in the same way we do with fees.

```diff
-        swap_count++;
-        // Fee-on-transfer
-        if (swap_count >= SWAP_COUNT_MAX) {
-            swap_count = 0;
-            outputToken.safeTransfer(msg.sender, 1_000_000_000_000_000_000);
-        }
```

## Medium

### [M-1] `TSwapPool::deposit` is missing the `deadline` check, causing the tx to finish even after deadline.

**Description:** The `deposit` function accepts a deadline as input which according to documentation is "The deadline for the transaction to be completed by", unfortunately nowhere in the function deadline is used. As a consequence, it would allow operations to add liquidity to the pool even after deadline is over at unfavorable rates.

**Impact:** Transaction could be sent when market conditions are unforable to deposit, even when adding the deadline parameter.

**Proof of Concept:** The `deadline` check is not used.

**Recommended Mitigation:**

```diff
    function deposit(
        uint256 wethToDeposit,
        uint256 minimumLiquidityTokensToMint,
        uint256 maximumPoolTokensToDeposit,
        uint64 deadline
    )
        external
+       revertIfDeadlinePassed(deadline)
        revertIfZero(wethToDeposit)
        returns (uint256 liquidityTokensToMint)
    {
```

## Low

### [L-1] `TSwapPool::LiquidityAdded` event has out of order parameters.

**Description:** Values called in `LiquidityAdded` event is being called incorrectly. The `poolTokensToDeposit` and `wethToDeposit` should be in 3rd and 2nd position respectively.

**Impact:** Event will emit incorrect data, potentially causing off-chain malfunctioning.

**Recommended Mitigation:**

```diff
- emit LiquidityAdded(msg.sender, poolTokensToDeposit, wethToDeposit);
+ emit LiquidityAdded(msg.sender, wethToDeposit, poolTokensToDeposit);
```

### [L-2] `TSwapPool::swapExactInput` returns incorrect values.

**Description:** The `swapExactInput` function is supposed to return actual value of tokens bought by the caller, it is called however it is never declated or uses an explicit return statement.

**Impact:** The return value will always be 0, giving incorrect info.

**Recommended Mitigation:**

```diff
 uint256 inputReserves = inputToken.balanceOf(address(this));
        uint256 outputReserves = outputToken.balanceOf(address(this));

-       uint256 outputAmount = getOutputAmountBasedOnInput(inputAmount, inputReserves, outputReserves);
+       output = getOutputAmountBasedOnInput(inputAmount, inputReserves, outputReserves);
-        if (outputAmount < minOutputAmount) {
-           revert TSwapPool__OutputTooLow(outputAmount, minOutputAmount);
-       }
+        if (output < minOutputAmount) {
+           revert TSwapPool__OutputTooLow(output, minOutputAmount);
+       }

-        _swap(inputToken, inputAmount, outputToken, outputAmount);
+        _swap(inputToken, inputAmount, outputToken, output);
```

## Informationals

### [I-1] `PoolFactory::PoolFactory__PoolDoesNotExist` is a unused variable and should be removed.

```diff
- error PoolFactory__PoolDoesNotExist(address tokenAddress);
```

### [I-2] `PoolFactory:createPpp;` is being assigned `.name()` instead of `.symbol()`

```diff
 string memory liquidityTokenSymbol = string.concat(
            "ts",
-            IERC20(tokenAddress).name()
+            IERC20(tokenAddress).symbol()
        );
```

## [I-3]: Event is missing `indexed` fields

Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

- Found in src/PoolFactory.sol [Line: 35](src/PoolFactory.sol#L35)

  ```solidity
      event PoolCreated(address tokenAddress, address poolAddress);
  ```

- Found in src/TSwapPool.sol [Line: 52](src/TSwapPool.sol#L52)

  ```solidity
      event LiquidityAdded(
  ```

- Found in src/TSwapPool.sol [Line: 57](src/TSwapPool.sol#L57)

  ```solidity
      event LiquidityRemoved(
  ```

- Found in src/TSwapPool.sol [Line: 62](src/TSwapPool.sol#L62)

  ```solidity
      event Swap(
  ```
