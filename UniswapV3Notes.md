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