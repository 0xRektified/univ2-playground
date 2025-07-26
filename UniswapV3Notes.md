# Basic Uniswap V3

## Concentrate liquidity

Liquidity is bounded within some price range the purpose is to be able tu support a widthest price range
with a lower amount of liquidity.

![image](./UniswapV3img/1-liquidity.png)

We basically amplified it by 200x

## Differences between Uniswap V2 and Uniswap V3

### V2

- Track reserve X and Y to calculate liquidity `XY = L^2` and price `P = Y/X`.
- Passive liquidity management (ERC20)
- One fee Tier (0.3%)
- TWAP - arithmetic mean

### V3

- Track liquidity and price to calculate Reserve X and Y between price ranges Pa and Pb

x = L / sqrt(Pa) - L / sqrt(Pb)
y = L * sqrt(Pb) - L * sqrt(Pa)

- Active liquidity management (ERC721)
- Several fee tiers (0.01%, 0.05%, 0.3%, 1%)
- Twap - geomtric mean

### Pro of V3

- Higher capital efficiency for LP
- Single sided liquidity (range limit order)

### Con of V3

- Active liquidity management
- NonFungible token

## Price and Liquidity

Price is track using the Tick the follow way:

P= 1.0001^t
where t = tick

To provide liquidity in uniswapV3 we need to create a position.
A position represent the liquidity concentrated in a price range.

![image](./UniswapV3img/2-liquidity-position-overlap.png)

We can see in this plot how the position overlap and liquidity increase.

## Important repository

### V3-periphery

#### NonFungiblePositionManager

Manage your position when add and remove liquidity and collect fee

`mint` method is actually used to mint a new position in the uniswapV3Pool contract.
The liquidity will be represented as an erc721.
`burn` to remove liquidity and `collect` to collection position fees.

`increase/liquidity` and `decreaseLiquidity` toupdate the position liquidity

#### SwapRouter

### V3-core

#### UniswapV3Factory

Deploy pools by calling `CreatePool` that will call the uniswapV3Pool contract 

#### UniswapV3Pool

Add/remove liquidity and swaps (mint, burn, collect, swap, flash)

All this function have a **callback** meaning the caller should be a contract, the best way to deploy ta new pool is to call the 
`NonFungiblePositionManager` contract with the `mint` function.

`flash` is used to get a flash loan there is also a callback so it needed to be called by a smart contract.

`swap` here we also need to send token before calling the swap function. There is a callback to the caller to do so.
So it also need to be called by a contract

### swap-router-contracts

#### SwapRouter02

The router contract is one calling the `swap` method from uniswapV3Pool contract.
The user can call `exactInputSingle` or `exactInput` to swap a specific amount of token in for a specific amount of token out.
or `exactOutputSingle` or `exactOutput` to swap a specific amount of token out for a specific amount of token in.

exactOutput/Input will swap between multiple pools.

#### universal-router

Allow you to swap between v2 v3 and nft

## Spot Price

To calculate the spot price we need the current price `sqrtPricex96` and the `tick`
Based on the slot0 structure we get all the data needed to know the spot price

```solidity
    struct Slot0 {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
        // the most-recently updated index of the observations array
        uint16 observationIndex;
        // the current maximum number of observations that are being stored
        uint16 observationCardinality;
        // the next maximum number of observations to store, triggered in observations.write
        uint16 observationCardinalityNext;
        // the current protocol fee as a percentage of the swap fee taken on withdrawal
        // represented as an integer denominator (1/x)%
        uint8 feeProtocol;
        // whether the pool is locked
        bool unlocked;
    }
```


### Price and tick

X = token0
Y = token1

P = price of X in terms of Y = Y/X
P = 1.0001^tick

Calculatiohn example

```python
    # WETH / USDT p[ool 0.3%
    # Calculate price form tick

    tick = -194624
    p = 1.0001 ** tick
    
    # p = y / x = price of token0 in terms of token1
    #                       WETH               USDT
    # 1 WETH = 1e18
    # 1 USDT = 1e6
    # 1 WETH = 1e18 / 1e6 = 1e12
    print(p) #3.5319103213169284e-09

    # To get the correct price we need to adjust the decimals as WETH and USDT don't have the same decimals
    print(p / 1e6 * 1e18) #3531.9103213169287
```

```python
    # USDC / WETH pool 0.05%
    # Calculate price form tick

    
    # p = y / x = price of token0 in terms of token1
    #                       USDC               WETH
    # Here we ll get the price of USDC in term of WETH so we need to reverse the price calculation
    # 1 / p = x / y = price of WETH in terms of USDC

    tick = 194609
    p = 1.0001 ** tick
    print(p) # 282708536.8770063 this number is off As it's the number of WETH for 1 USDC
    # 1 USDC = 1e6 = x
    # 1 WETH = 1e18 = y
    # p = y / x = WETH / USDC = 1e18 / 1e6 = 1e12
    print(p /1e18*1e6) #0.0002827085368770063

    print(1/p) # 3.537211896912242e-09 this number is small because we didn't do the decimal converter
    # 1 USDC = 1e6 = x
    # 1 WETH = 1e18 = y
    # 1 / p = x / y = USDC / WETH = 1e6 / 1e18 = 1e-12
    print(1 / p /1e6*1e18) # 3537.211896912242
```

### Price and sqrtPricex96

sqrtPricex96 = sqrt(P)Q96

Q96 = 2^96

p = (sqrtPricex96 / Q96)^2

```python
# WETH / USDT pool 0.3%
# Calculate price for sqrtPriceX96

sqrt_p_x96 = 4599602858753747432741081
Q96 = 2 ** 96
p = (sqrt_p_x96 / Q96)**2 # 3.370400441176277e-09

# p = y / x = USDT / WETH = 1e6 / 1e18 = 1e-12
print(p)
print(p / 1e6 * 1e18) # 3370.400441176277
```

sqrtPriceX96 and tick

p = 1.0001^tick = (sqrtPriceX96/Q96)^2

tick = (2 log(sqrtPriceX96/Q96)) / log(1.0001)

```python

import math
#USDC / WETH 0.05% pool
# Calculate tick from sqrtPriceX96

Q96 = 2 ** 96
sqrt_p_x96 = 1386025840740905446350612632896904
tick = 195402

t = 2* math.log(sqrt_p_x96 / Q96) / math.log(1.0001)
print(t) # 195402.15505159998

```

### Price calculation with solidity

```solidity
        // P = Y /X = WETH / USDC
        //          = price of USDC in terms of WETH
        // 1 / P = X / Y = USDC / WETH
        //          = price of WETH in terms of USDC

        // DECIMALS

        // P has 1e18 / 1e6 = 1e12 decimals
        // 1 / P has 1e6 / 1e18 = 1e12 decimals 

        IUniswapV3Pool.Slot0 memory slot0 = pool.slot0();

        // sqrtPriceX96 * sqrtPriceX96 might overflow

        // sqrtPriceX96 = sqrt(P) * 96
        // Q96 = 2 ** 96
        // sqrtPriceX96 * sqrtPriceX96 = sqrt(P) * Q96 * sqrt(P) * Q96
        //                             = P * Q96 * Q96 
        //                               2 * 96 bits = 192 bits
        //                             256 bites - 192 bits = 64 bits
        //                             2**64 / 1e18 = approx eq = 18

        // sqrtPriceX96 / Q96 * sqrtPriceX96 / Q96 = P
        // Problem is it could round to zero and price will be innacurate
        // Here we only use on Q96 to keep precision and will add it later
        uint256 price = FullMath.mulDiv(slot0.sqrtPriceX96, slot0.sqrtPriceX96, Q96);


        console2.log("price_raw %e", price);

        // price = sqrt(P) * Q96 * sqrt(P) * Q96 / Q96
        //      = P * Q96

        // 1 / price = 1 / (P * Q96)
        // it could return 0 because of a low number
        // price = 1 / price

        // First we cancel out the first Q96 by multipliying by Q96
        // price = Q96 / price

        // 1 / P has 1e6 / 1e18 = 1e12 decimals
        // price = 1e12 * Q96 / price

        // FInally we want to return the price with 18 decimals

        price = 1e18 * 1e12 * Q96 / price;

        assertGt(price, 0, "price = 0");
        console2.log("price %e", price);
```

## Math

#### Definition

liquidity squared equals the product of reserves

XY = L²

price is the ratio of token Y to token X

Y/X = P

#### Equation for X

L² / P = XY / (Y/X) = X²

L² / P - Starting expression

XY / (Y/X) - Substituting definitions:
    - L² = XY (liquidity squared equals the product of reserves)
    - P = Y/X (price is the ratio of token Y to token X)

- Simplifying the division:
 XY / (Y/X) = XY × (X/Y) = XY × X/Y = X²

L² / P = X² means that if you know the liquidity and price,
   you can calculate the amount of token X

Rearranging: X = √(L² / P) = L / √P

**Note**

`X = L / √P`

#### Equation for Y

XY = L²  AND  Y/X = P

L²P = XY . Y/X
L²P = Y²

Simplified

Y = L * √P

If you know the liquidity and price, you can calculate the amount of token Y

**Note**

`Y = L * √P`

#### Curve of the real reserve

XY = L²

Total token = real amount and virtual amount 

X = Xr+ Xv
Y = Yr+ Yv

XY = (Xr + Xv)(Yr + Yv) = L²

- Find Xv and Yv

- When Xr = 0 

(Xr + Xv)(Yr + Yv) = L²

Xv(Yr + Yv) = L²

`Xv = L² / (Yr + Yv) `

Based on the note above

`Y = Yr+ Yv = L * √P`

So `L² / (Yr + Yv)` is equal to `L² / L * √P`

`L² / L * √P` can be simplified to `L / sqrt(P)`

Xv = L / sqrt(Pb)

- When Yr = 0

(Xr + Xv)(Yr + Yv) = L²

Yv(Xr + Xv) = L²

`Yv = L² / (Xr + Xv)`

Based on the note above

Xr + Xv = X = L / √P

So `L² / (Xr + Xv)` is equal to `L² / L / √P`

`L² / (L / √P)` can be simplified to `L * sqrt(P)`

  Step-by-step simplification:
  1. L² / (L / √P)
  2. = L² × (√P / L)    [dividing by a fraction = multiplying by its reciprocal]
  3. = (L² × √P) / L    [rearranging]
  4. = L × √P           [L²/L = L]

Yv = L * sqrt(Pa)

 So this formula shows how to calculate the amount of token Y
  when you know the liquidity L and the amount of token X.

![image](./UniswapV3img/3-curve-of-real-and-virtual-reserve.png)

#### Amount of token between price ranges

Given L and P 

What is the amount of x Between P and Pb ?

x = L / sqrt(P)

x =  L / sqrt(P) - L / sqrt(Pb)

OR for simplicity

x =  L / sqrt(P_lower) - L / sqrt(P_upper)

What is the amount of y between P and Pa ?

y = L * sqrt(P)

y =L * sqrt(P) -  L * sqrt(Pa) 

OR for simplicity

y =L * sqrt(P_upper) -  L * sqrt(P_lower)


## Swap

### Flow

- Inputs

Zero for one (token0 -> token1 ?)
amount specified sqrt(P limit)

exact input = amount specified ?= 0

- Loop

Calculate amount in and out BELLOW

While amount specified remaining != 0 and sqrt(P) != sqrt(Plimit)

Get next tick

calculate sqrt(Pnext)
calculate sqrt(P) , amount in , out , fee

-> need liquidity , amount specified remaining
--> Call `computeSwapStep`

--> For exact input calculate max amout in between sqrt(p) and sqrt(Ptarget) which is next
--> For exact output calculate max amout out between sqrt(p) and sqrt(Ptarget) which is next

--> calculate sqrt(Pnext)
--> Calculate amount in and out and fee

![image](./UniswapV3img/4-ptarget-pnext.png)

* exact input
amount specified remaining -= amount in + fee
amount calculated -= amount out

OR

* exact output
amount specified remaining += amount out
amount calculated += amount in + fee

update local variables liqidity , sqrt(p) , tick, fee

Then END of the loop

- Update state variable liquidity , sqrt(p), tick, fee growth

- Send token out

- swap call back (msg.sender token in)

- check token in balance


### Current active liquidity

Liquidity net

![image](./UniswapV3img/5-liquidity-net.png)

When the price cross the tick upper or lower 

we multiple current liquidity by the direction of the price by liquidity net (delta liquidity)
to get next liquidity.

![image](./UniswapV3img/6-liquidity-visual.png)

## Delta price

What is the price after adding or removing DeltaX ?

### Add delta X from Pupper

price decreases from Pupper to Plower

**Starting equation:**

delta_x = L / sqrt(P_lower) - L / sqrt(P_upper)

**Step 1: Rearrange to isolate L / sqrt(P_lower)**

L / sqrt(P_upper) + delta_x = L / sqrt(P_lower)

**Step 2: Multiply both sides by sqrt(P_upper)**

(L / sqrt(P_upper) + delta_x) × sqrt(P_upper) = (L / 
sqrt(P_lower)) × sqrt(P_upper)

**Step 3: Distribute on the left side**

L + delta_x × sqrt(P_upper) = L × sqrt(P_upper) / sqrt(P_lower)

**Step 4: Cross multiply (multiply both sides by sqrt(P_lower))**

(L + delta_x × sqrt(P_upper)) × sqrt(P_lower) = L × sqrt(P_upper)

**Step 5: Solve for sqrt(P_lower)**

sqrt(P_lower) = (L × sqrt(P_upper)) / (L + delta_x × 
sqrt(P_upper))

**Final result:**

sqrt(P_lower) = L × sqrt(P_upper) / (L + delta_x × sqrt(P_upper))

### Remove delta X from Pupper

price increases from Plower to Pupper 

**Starting equation:**

delta_x = L / sqrt(P_lower) - L / sqrt(P_upper)

**Step 1: Rearrange to isolate L / sqrt(P_upper)**

L / sqrt(P_upper) = L / sqrt(P_lower) - delta_x

**Step 2: Take reciprocals of both sides**

sqrt(P_upper) / L = 1 / (L / sqrt(P_lower) - delta_x)

**Step 3: Simplify the right side (find common denominator)**

sqrt(P_upper) / L = 1 / ((L - delta_x × sqrt(P_lower)) / 
sqrt(P_lower))

**Step 4: Simplify division by fraction**

sqrt(P_upper) / L = sqrt(P_lower) / (L - delta_x × sqrt(P_lower))

**Step 5: Cross multiply**

sqrt(P_upper) × (L - delta_x × sqrt(P_lower)) = L × sqrt(P_lower)

**Step 6: Solve for sqrt(P_upper)**

sqrt(P_upper) = L × sqrt(P_lower) / (L - delta_x × sqrt(P_lower))

**Final result:**

sqrt(P_lower) = L × sqrt(P_lower) / (L - delta_x × sqrt(P_lower))

---

What is the price after adding or removing DeltaY ?

### Add delta Y from Pupper

price increase from Plower to Pupper

**Starting equation:**

delta_y = L * sqrt(P_upper) - L * sqrt(P_lower)

**Step 1: Rearrange to isolate sqrt(P_upper)**

L * sqrt(P_upper) = delta_y + L * sqrt(P_lower)

**Step 2: Divide both sides by L**

sqrt(P_upper) = delta_y / L + sqrt(P_lower)

**Final result:**

sqrt(P_upper) = delta_y / L + sqrt(P_lower)


### Remove delta Y from Pupper

price decreases from Pupper to Plower

**Starting equation:**

delta_y = L * sqrt(P_lower) - L * sqrt(P_upper)

**Step 1: Rearrange to isolate sqrt(P_lower)**

L * sqrt(P_lower) = delta_y + L * sqrt(P_upper)

**Step 2: Divide both sides by L**

sqrt(P_lower) = delta_y / L + sqrt(P_upper)

**Final result:**

sqrt(P_lower) = delta_y / L + sqrt(P_upper) 


## Math Swap fee

Swap fee is charged from amount in

f = swap fee percentage 0<= f <= 1

A = amount in before swap fee

fee = swap fee = Af

Ain = amount in after swap fee
    = A - fee <= max maount in
Aout = amount out <= max amount out

### Exact Out

Find max amount out -> calculate -> Aout - > calculate Ain -> calculate Fee
From P to Pa

Ain = A - fee = A - Af = A(1-f)

Ain/1-f = A

Fee = Af = (Ain/1-f) * f

### Exact In

#### Ain = max amount in

Fee = (Ain/1-f) * f

#### Ain < max amount in

Basically the amountRemaining minus the amountIn

Fee = A - Ain = A - (A - Fee) = Fee


## Code Walkthrough Swap


### important struct

`Slot0` struct is used to save gas
Observation are used for price oracle

### Params
`recipient` - receiver of token out
`zeroForOne` - token zero come in token1 go out
`Int256 amountSpecified` - can be pos or neg
⚠️ If the number is positive it mean it’s an exact input
⚠️ if amount is neg It mean the user specify how much he want and the protocol will calculate the amount out

`sqrtPricelimitX96` // x * (2 **96) 
`data` // the amount used in the callback

We pass the amount in the callback


The function have a reentrancy guard

SwapCache is used to save gas

Then we check if it’s exact input but checking if number is positiv or negative 

Save state value in SwapState

Then While loop

We are one swapping in the bar that represent current liquidity , we check how much go in and out

Looping untill reach the about specified remain

Inside the TickBitmap.sol library there is a 

`nextInitializedTickWithOneWord` 

This function gonna return the next init or unit tick from the current tick we check if it ’s between the min and max tick


Then we calculate the sqrtPriceNext96

If swap is exact input or output we apply this logic:
If swap is exact it ll deduct the amount to come in + fee
Other out it ll add amount out to specified remaining

In both cases it ll approach 0 

For exactInput it ll start from positive number and go close to 0
For exactOutput it start from negative number and go close to 0

```            if (exactInput) {
                state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount).toInt256();
                state.amountCalculated = state.amountCalculated.sub(step.amountOut.toInt256());
            } else {
                state.amountSpecifiedRemaining += step.amountOut.toInt256();
                state.amountCalculated = state.amountCalculated.add((step.amountIn + step.feeAmount).toInt256());
            }
```

Then we calculate the fee using feeGrowthGlobalX128


If current sqrtX96 reach the nextsqrtX96 and tick is initialise it ll store variable for price oracle


It ll get the liquidity net and update the active liquidity

At the end of the loop it ll update the tick

---

Amount in and out are calculated the following way
```// zero for one | exact input | //       true        |      true        |  amount 0 = specified - remaining ( > 0)
//                                            | amount 1 = calculated                     ( < 0)
//       false       |      false       | amount 0 = specified - remaining ( < 0)
//						| amount 1 = calculated		    ( > 0)
//       false       |      true        | amount 0 = calculated
//						| amount 1 = specified - remaining ( > 0)
//       true        |      false       | amount 0 = calculated
//						| specified - remaining ( < 0)
        (amount0, amount1) = zeroForOne == exactInput
            ? (amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated)
            : (state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining);
```

Last part it’s gonna transfer token out and call the call back
```        if (zeroForOne) {
            if (amount1 < 0) TransferHelper.safeTransfer(token1, recipient, uint256(-amount1));

            uint256 balance0Before = balance0();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
            require(balance0Before.add(uint256(amount0)) <= balance0(), 'IIA');
        } else {
            if (amount0 < 0) TransferHelper.safeTransfer(token0, recipient, uint256(-amount0));

            uint256 balance1Before = balance1();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
            require(balance1Before.add(uint256(amount1)) <= balance1(), 'IIA');
        }
```
msg.sender will send the amount request, and check the balance of token0

### Function interaction

ExactInputSingleParams
ExactInputParams
ExactOutputSingleParams
ExactOutputParams

Each of those function are calling ExactInputInternal or ExactOutputInternal

Inside those function there is an internal data that is olding the path

it encode the 2 tokens and the fees which identify the pool to swap one

the type is bytes

path = [token, fee, token, fee ...]

Example:

DAI -> USDC -> WETH
   0.01%    0.3%

path = [DAI , 100, USDC, 3000, WETH]

Fee is scaled up by 1000

#### `ExactInput single`

path = [token in, fee, token out]

![image](./UniswapV3img/7-swap-single-flow.png)

Call trace example of `ExactInput single`


exactInput(path = [A, fee, B , fee, C , fee, D])
payer = user
--> while loop
--> exactinputInternal(recipient = router)
---> swap A/B
----> transfer B to recipient
-----> uniswapV3SwapCallback
------> transfer A from user to pool A/B

--> payer = router
--> path = [B, fee, C , fee, D]
--> while loop
--> exactinputInternal(recipient = router)
---> swap B/C
----> transfer C to recipient
-----> uniswapV3SwapCallback
------> transfer B from router to pool B/C

--> payer = router
--> path = [C, fee, D]
--> while loop
--> exactinputInternal(recipient = user)
---> swap C/D
----> transfer D to recipient
-----> uniswapV3SwapCallback
------> transfer C from router to pool C/D

#### `ExactOutput single`

path = [token out, fee, token in]

![image](./UniswapV3img/8-swap-single-out-flow.png)

For swap A -> B -> C -> D
Swap will happen in the reverse order

first swap will happen with C/D

![image](./UniswapV3img/9-swap-token-out-revert-order.png)

Call trace example of `ExactOutput single`

exactOutput(path = [D, fee, C , fee, B , fee, A])
payer = user
--> while loop
--> exactoutputInternal(recipient = user)
---> swap C/D
----> transfer D to recipient (user receive token)
-----> uniswapV3SwapCallback
------> path = [C, fee, B, fee, A]
------> exactoutputInternal(recipient = C/D) (recursive call)
------> swap B/C
------> transfer C to recipient
-------> uniswapV3SwapCallback
-------> path = [B, fee, A]
-------> exactoutputInternal(recipient = B/C) (recursive call)
-------> swap A/B
-------> transfer B to recipient
-------> uniswapV3SwapCallback
-------> transfer A from user to pool A/B (User finally pay)


## Code walkthrough V3SwapRouter02

`ExactInputSingle`

Used to swap specific token in for out (calculate by pool), it ll only swap for single pool 

Call exactInputInternal.
[DAI, 100, USDC, 3000, WETH] path should be encoded this way
--> use data.path.decodeFirstPool() to get the pool

Then it call the function swap on the pool

in the uniswap v3 pool contract the V3 callback will be executed in the router

In uniswapV3SwapCallback if exact input it ll use data.apyer and msg.sender to transfer token out

Then the swap function will return the amount0 and amount1

`ExactInput`

Used to swap specific token in for out (calculate by pool), it ll only swap for multiple pool

Inside this function there is a while loop for multiple pools
if there is multiple pool it ll set the payer as the router

on each iteration it ll call `exactInputInternal`
When the path have no more pool it ll exit

`ExactOutputSingle`

Called when a user want to swap a specific amount of token out for a specific pool contract

It call the exactOutputInternal path is encoded the other way as tokenIn So tokenOut is first

logic is kinda the same as previously

`ExactOutput`

The difference between the previous one is this function only call exactOutputInternal recursively

The callback is the one calling the exactOutputInternal recursively if there is multiple pools.

When the path doesn't have multiple pool anymore it call the `pay() method and wrap up the recursive.

## Swap playground

Each of this method are demonstrated in the test/uniswapV3.

## Factory

### How the factory contract deploy the pool contract

how does Create2 compute the address

```
address = keccak256(
    0xFF,
    deployer, // the address that deploy the contract
    salt, // specified byt the deployer
    keccak256(creation bytecode, constructor inputs) // the creation bytecode of the contract and the constructor arguments
    )
```

### Uniswap V3 pool address

address = last 20 bytes of keccak256(
    0xFF,
    deployer = factory contract
    salt = keccak256(token 0 , token 1, fee)
    keccak256(
        creation bytecode // uniswapV3Pool
        // No constructor inputs
        )
    )
    
- Pool address determined by token0 token1 and fee

Salt and constructor inputs are dynamic

- Initialize contract with parameters
 token0, token1, fee, factory, address, tick Spacing

Solution is to use the salt = keccak256 (token0, token 1, fee)
No constructor input
Temporary store the initialization inputs inside the factory


### Creation Flow

User call creatPool(token0, token1, fee)
-> deploy(factory, token0, token1, fee, tickSpacing)
--> store parameters
--> new uniswapV3Pool() <- salt = keccak256(token0, token1, fee)
---> get parameter from msg.sender
-> delete parameters

### Pool creation playground

demonstrate get pool address and create a pool in test/uniswapV3/UniswapV3Factory.t.sol

## Flash swap

Flash in V3 work differently as V2 as there is a dedicated function `flash` to call it

Parameters are recipient, amount0, amount1, data.

We need to implement the callback function `uniswapV3FlashCallback` in our contract that will be called by the pool contract. parameters are fee0, fee1, data.

## Liquidity

Where P is currrent price

Find liquidity L given x , y , P , Plower, Pupper

x and y in Ploower to Pupper

x = L / sqrt(Plower) - L / sqrt(Pupper)

y = L * (sqrt(Pupper) - sqrt(Plower))

### When P <= Pa

x = L / sqrt(Plower) - L / sqrt(Pupper)

L = x / (1/sqrt(Pa)) - (1/sqrt(Pb)) = x * sqrt(Pa) * sqrt(Pb) / (sqrt(Pb) - sqrt(Pa))

### When Pb <= p

y = L * (sqrt(Pupper) - sqrt(Plower))

L = y / (sqrt(Pb) - sqrt(Pa)) = y * sqrt(Pa) * sqrt(Pb) / (sqrt(Pb) - sqrt(Pa))

### When Pa < P < Pb

Lx = liquidity from P to Pb

Lx = x / (1/sqrt(P)) - (1/sqrt(Pb)) 

Ly = liquidity from Pa to P

Ly = y / (sqrt(P) - sqrt(Pa))

### Liquidity delta

L0 = liquidity before

L1 = liquidity after

deltaL = L1 - L0

how much delatX and deltaY to add or remove if liquidity changes by deltaL between Pa and Pb ?