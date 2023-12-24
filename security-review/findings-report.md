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

### [H-3] `TSwapPool::sellPoolTokens` mismatches input and output tokens causing users to recieve incorrect amount of tokens.

**Description:** The `sellPoolTokens` function is supposed to allow users to sell pool tokens in exchange for WETH. Users indicate how much tokens they are willing to sell in `poolTokenAmount`. However the function used to calculate those tokens is the incorrect one.

Instead of calling `swapExactOutput`, we should be calling `swapExactInput`. Because we want user to specify the input amount, not the output.

**Impact:** User will swap wrong armount of tokens, which will break the functionality.

**Proof of Concept:**

**Recommended Mitigation:**

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
