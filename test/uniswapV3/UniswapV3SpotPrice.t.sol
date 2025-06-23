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

    function test_spot_price_sqrtPriceX96() public {
        uint256 price = 0;
        IUniswapV3Pool.Slot0 memory slot0 = pool.slot0();
        console2.log("test", slot0.sqrtPriceX96);
        assertGt(price, 0, "price = 0");
        console2.log("price %e", price);
    }
}
