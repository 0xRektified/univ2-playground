// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IUniswapV2Pair} from "../../interfaces/IUniswapV2Pair.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IUniswapV2Router02} from "../../interfaces/IUniswapV2Router02.sol";
import {IWETH} from "../../interfaces/IWETH.sol";
import {UniswapV2Arb2} from "../../src/UniswapV2/UniswapV2Arb2.sol";
import {IUniswapV2Factory} from "../../interfaces/IUniswapV2Factory.sol";

// Test arbitrage between Uniswap and Sushiswap
// Buy WETH on Uniswap, sell on Sushiswap.
// For flashSwap, borrow DAI from DAI/MKR pair
contract UniswapV2Arb2Test is Test {
    address constant SUSHISWAP_V2_ROUTER_02 = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address constant UNISWAP_V2_ROUTER_02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant SUSHISWAP_V2_FACTORY = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    IUniswapV2Factory private constant uni_factory = IUniswapV2Factory(UNISWAP_V2_FACTORY);
    IUniswapV2Factory private constant sushi_factory = IUniswapV2Factory(SUSHISWAP_V2_FACTORY);
    IUniswapV2Router02 private constant uni_router = IUniswapV2Router02(UNISWAP_V2_ROUTER_02);
    IERC20 private constant dai = IERC20(DAI);
    IWETH private constant weth = IWETH(WETH);
    address constant user = address(17547257);

    UniswapV2Arb2 private arb;

    function setUp() public {
        arb = new UniswapV2Arb2();

        // Setup - WETH cheaper on Uniswap than Sushiswap
        deal(address(this), 100 * 1e18);

        weth.deposit{value: 100 * 1e18}();
        weth.approve(address(uni_router), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = DAI;

        uni_router.swapExactTokensForTokens({
            amountIn: 100 * 1e18,
            amountOutMin: 1,
            path: path,
            to: user,
            deadline: block.timestamp
        });
    }

    function test_flashSwap() public {
        uint256 bal0 = dai.balanceOf(user);

        vm.startPrank(user);
        arb.flashSwap(uni_factory.getPair(DAI, WETH), sushi_factory.getPair(DAI, WETH), true, 10000 * 1e18, 1);
        vm.stopPrank();
        uint256 bal1 = dai.balanceOf(user);

        assertGt(bal1, bal0, "no profit");
        assertEq(dai.balanceOf(address(arb)), 0, "DAI balance of arb != 0");
    }
}
