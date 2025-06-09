# Basic Uniswap V2

The function used for the constant product AMM is defined as:

```Solidity
x * y = L ^ 2
```

Where:

* x = amount of token X

* y = amount of token Y

* L = liquidit

**Example:**

In this example, we see an AMM where:

* x = 200

* y = 200

* L = 200

This means the liquidity of the AMM is 200, and all combinations of token X and token Y that satisfy the function `x * y = L ^ 2` are valid.

![image](./Screenshot%202025-06-08%20at%2016.26.35.png)


# Swap

## 📘 Uniswap V2 Swap Graph – Summary of Key Formulas

### 🔹 Invariant
- `x * y = L²`  
  The constant product rule that the pool maintains.

### 🔹 Curve Equation
- `y = L² / x`  
  The shape of the swap curve (a hyperbola).

### 🔹 Initial Price (Tangent Slope)
- `p₀ = -y₀ / x₀`  
  The instantaneous price before the trade (marginal price).

### 🔹 Swap Price (Average Execution Price)
- `p_swap = dy / dx`  
  The actual price paid during the swap.

### 🔹 Swap Equation (Preserving the Invariant)
- `(x₀ + dx)(y₀ - dy) = x₀ * y₀`  
  Ensures that the product stays constant after the swap.

### 🔹 Solving for dy
- `dy = y₀ - (x₀ * y₀) / (x₀ + dx)`  
  How much of token Y the trader receives.

### 🔹 Final Simplified Form of dy
- `dy = (y₀ * dx) / (x₀ + dx)`  
  Clean and practical formula for output amount.

### 🔹 Tangent Line Equation
- `y = p₀ * (x - x₀) + y₀`  
  Linear approximation of the curve at the initial point.

### 🔹 Swap Line Equation
- `y = p_swap * (x - x₀) + y₀`  
  Line connecting the trade input and output points.

##  Swap Math

If (x_0 + dx)(y_0 - dy) = L^2 final equation after a swap

Since both expressions equal L^2, we can say:

(x₀ + dx)(y₀ - dy) = x₀ · y₀

Divide both sides by (x₀ + dx):

y₀ - dy = (x₀ · y₀) / (x₀ + dx)

Solve for dy:

dy = y₀ - (x₀ · y₀) / (x₀ + dx)

Factor out y₀:

dy = y₀ · (1 - x₀ / (x₀ + dx))

Simplify the fraction:

dy = y₀ · (dx / (x₀ + dx))

✅ Final form:

dy = (y₀ · dx) / (x₀ + dx)

##  Swap Fee

swap fee rate is 0 < F < 1 where 1 is 100%

swap fees = Fdx

dy = (dx · (1-F) · y₀) / (x₀ + dx · (1-F))

Example:

F = 0.003
x₀ = 6_000_000
y₀ = 3000
dx = 1000

dy = (dx · (1-F) · y₀) / (x₀ + dx · (1-F))

dy = (1000 · (1-0.003) · 3000) / (6_000_000 + 1000 · (1-0.003))

dy = 0.4984171796786434

##  Swap comtract call

Basic swap contract call:

![image](./Screenshot%202025-06-08%20at%2018.30.25.png)

Multi-hop swap

![image](./Screenshot%202025-06-08%20at%2018.32.59.png)

##  Swap Line tangeant and Line swap

From the graph:

`P₀` is the instantaneous price, this is the derivative of the curve at that point

`Pswap` is the effective swap price, how much of token Y you get per unit of token X. It’s not constant — it depends on the size of the trade due to slippage


	•	p₀ = -y₀ / x₀ → the initial slope, a linear approximation of the price at that point
	•	p_swap = dy / dx → the actual execution price of the trade


	•	y = p₀(x - x₀) + y₀ (orange line): linear approximation of the curve at (x₀, y₀)
	•	y = p_swap(x - x₀) + y₀ (red line): line showing the direction/price path of the actual swap

![image](./Screenshot%202025-06-09%20at%2011.04.35.png)

# Code repo

## V2-periphery

### Router

Usefull for multi-hop

https://github.com/Uniswap/uniswap-v2-periphery/contract/UniswapV2Router02.sol


#### swapExactTokensForTokens PATH

```java
    // NOTE: swap all input for max output
    // in = 1000 dai
    // out = max WETH
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        // NOTE: calculates swap outputs
        // amounts[0] = input, amounts[last] = output, amounts[rest] = intermediate outputs
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');

        // NOTE creat2 pair address
        // Directly send token in to pair
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }
```

```java

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        // NOTE
        //    i | path[i]   | path [i + 1]
        //    0 | path[0]   | path [1]
        //    1 | path[1]   | path [2]
        //    2 | path[2]   | path [3]
        //    3 | path[n-2]   | path [n-1]
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));

            // NOTE: last swap -> send token out to "to" address
            // otherwise -> send to next pair contract
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            
            // NOTE : swap doesn't ask for amount in only amounts out
            IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
```

getAmountsOut

https://github.com/Uniswap/uniswap-v2-periphery/contract/libraries/UniswapV2Library.sol

```java
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    
    // NOTE : amoutns[0] = amountIN
    // amounts[n - 1] = Final aout
    // amoutns[i] = intermediate amount
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        // NOTE
        //    i | path[i]   | path [i + 1]
        //    0 | path[0]   | path [1]
        //    1 | path[1]   | path [2]
        //    2 | path[2]   | path [3]
        //    3 | path[n-2] | path [n-1]
        for (uint i; i < path.length - 1; i++) {
            // NOTE: reserves = internal balance of tokens inside pair contract
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            // NOTE: use the previous output for input
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
            // NOTE : example
            // path = [DAI, WETH]
            // amounts[0] = 1000 * 10 ** 18 DAI
            // amounts[1] = WETH amount out

            // path = [DAI, WETH, MKR]
            // amounts[0] = 1000 * 10 ** 18 DAI
            // amounts[1] = WETH amount out
            // amounts[2] = MKR amount out
        }
    }
```

calling amountOut

```java
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        // NOTE: 
        // x = token in
        // y = token out
        // F = 0.003
        //       dx * 0.997 * x0
        // dy = -------------
        //       d0 + dx * 0.997

        // NOTE:
        // dx * 997
        uint amountInWithFee = amountIn.mul(997);
        // dx * 997 * y0
        uint numerator = amountInWithFee.mul(reserveOut);
        // x0 * 1000 + dx * 997
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        // dy = (dx * 997 * y0) / (x0 * 1000 + dx * 997)
        // dy = (dx * 997/1000 * y0) / (x0 + dx * 997/1000)

        amountOut = numerator / denominator;
    }
```

Check playground and UniswapV2SwapAmountsTest for simple example of getAmountOut Usage

#### swapTokensForExactTokens

```java
    // NOTE: swap min input for specified output
    // max in = 3000 DAO
    // out = 1 WETH
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        // NOTE calculate amount in
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }
```

let's check amountsIn

```java
    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        // NOTE:
        //    i | output amount   | input amount
        //    n-1 | amounts[n-1]  | amounts[n-2]
        //    n-2 | amounts[n-2]  | amounts[n-3]
        // ...
        //    2 | amounts[2]      | amounts[1]
        //    1 | amounts[1]      | amounts[0]
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
```

Details of amountIn

```java
    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        // x0 * dy * 1000
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        // (y0 - dy) * 997
        uint denominator = reserveOut.sub(amountOut).mul(997);
        // NOTE: 
        
        // (x0 + dx * (1-F))(y0-dy) = x0 * y0
        //          x0 * dy         1
        // dx = -------------- * --------
        //          y0 - dy       1-f

        //          x0 * dy * 1000
        // dx = -------------------
        //         (y0 - dy) * 997
        // NOTE: round up
        amountIn = (numerator / denominator).add(1);
    }
```

### Pair

As the swap** methods are calling the swap method from the pair contract next we ll walk through uniswap pair contract

https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol


```java
    // this low-level function should be called from a contract which performs important safety checks
    // NOTE: no amount in for input
    // NoTE: data used for flash swap
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
        // NOTE: reserves = internal balance of tokens inside pair contract
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV2: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        // NOTE: stack too deep
        { // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, 'UniswapV2: INVALID_TO');
        // NOTE transfer out first
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
        if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        }
        // NOTE calculate amount in
        // actual balance - (internal balance - amount out)
        // actual balance = actual balance before transfer - amount out
        // actual balance > new internal balance ? balance increase -> amount in > 0 : 0
        // NOTE: example
        // amount in = token 0, amount out = token 1
        // amount0Out = 0
        // bamount1out = 100
        // amount in = 10 token 0 (sent before)
        // balance0 = 1010
        // reserve0 = 1000
        //                 1010        1000          0         1010        (1000 - 0) = 10
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
        // NOTE:
        // amount0In = 0 -> balance0Adjusted = balance0
        // amount0In > 0 -> balance0Adjusted = balance0 * 1000 -3 * amount0In
        // balance0Adjusted / 1000 = balance0 - 3 / 1000 * amount0In
        // balance0Adjusted = balance0 * 1000 - 3 * amount0In
        // balance0Adjusted / 1000 = balance0 - 3 / 1000 * amount0In
        uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
        uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
        // NOTE:
        //  x0 +  amount in    *   y0 - abount out
        // (x0 + dx * (1 - F)) * (y0 - dy) >= x0 * y0
        // balance0Adjusted / 1000 = balance0 - 3 / 1000 * amount0In
        // balance 0 adjusted * balance 1 adjusted
        // ----------------------------------------- >= reserve 0 * reserve 
        //                 1000 ** 2
        require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), 'UniswapV2: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }
```

Let's check what the _update method does, it update the local balance and the TWAP

```java
    // update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), 'UniswapV2: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            // NOTE: TWAP - Time weighted average price
            // * never overflows and + overflow is desired
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }
```

Exmaple for `swapExactTokensForTokens` and `swapTokensForExactTokens` in test/UniswapV2SwapAmountsTest.t.sol



## V2-core

### V2-pair and V2-factory

https://github.com/Uniswap/uniswap-v2-core


0xBd68dbE675d0d1108af3aEbC5F7724Cf31c82E9a