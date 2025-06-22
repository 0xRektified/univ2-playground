// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IUniswapV2Pair} from "../interfaces/IUniswapV2Pair.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {UniswapV2FlashSwap} from "../src/UniswapV2FlashSwap.sol";
import {IUniswapV2Pair} from "../interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "../interfaces/IUniswapV2Factory.sol";

// UniswapRouter02 private constant router = UniswapRouter02(UNISWAP_V2_ROUTER_02);
contract UniswapV2FlashSwapTest is Test {
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    IERC20 private constant dai = IERC20(DAI);
    IERC20 private constant weth = IERC20(WETH);
    address constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    IUniswapV2Factory private constant factory = IUniswapV2Factory(UNISWAP_V2_FACTORY);
    UniswapV2FlashSwap private flashSwap;

    address private constant user = address(100);
    address private pair;

    function setUp() public {
        pair = factory.getPair(WETH, DAI);
        flashSwap = new UniswapV2FlashSwap(pair);
    }

    function testFlashSwap() public {
        uint256 dai0 = dai.balanceOf(pair);
        vm.startPrank(user);
        deal(DAI, user, 10000 * 1e18);
        dai.approve(address(flashSwap), type(uint256).max);

        // user -> pair.swap
        // -> flashSwap.uniswapV2Call
        // -> token.transferFrom(user, flashSwap, fee)

        flashSwap.flashSwap(DAI, 1_000_000 * 1e18);

        uint256 dai1 = dai.balanceOf(pair);

        console2.log("DAI (fee):", dai1 - dai0);
        vm.stopPrank();
        console2.log("FlashSwap Balance:", dai.balanceOf(address(flashSwap)));
        console2.log("User Balance:", dai.balanceOf(user));

        // FlashSwap should have no DAI as swap is repayed
        assertEq(dai.balanceOf(address(flashSwap)), 0, "FlashSwap Balance");
        assertGt(dai1, dai0, "DAI balance of pair");
    }
}
