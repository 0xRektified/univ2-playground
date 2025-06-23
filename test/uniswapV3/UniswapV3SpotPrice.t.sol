// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IUniswapV3Pool} from "../../interfaces/uniswapV3/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "../../interfaces/uniswapV3/IUniswapV3Factory.sol";
import {FullMath} from "../../src/uniswapV3/libraries/FullMath.sol";

contract UniswapV3SpotPriceTest is Test {
    address constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // token0 (X)
    uint256 private constant USDC_DECIMALS = 1e6;

    // token1 (Y)
    uint256 private constant WETH_DECIMALS = 1e18;

    // 1 << 96 = 2 ** 96
    uint256 private constant Q96 = 1 << 96;
    IUniswapV3Factory private immutable factory = IUniswapV3Factory(UNISWAP_V3_FACTORY);
    IUniswapV3Pool private pool;

    function setUp() public {
        address poolAddress = factory.getPool(USDC, WETH, 500);
        pool = IUniswapV3Pool(poolAddress);
    }

    function test_spot_price_sqrtPriceX96() public view {

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
    }
}
