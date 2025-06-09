// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {IUniswapV2Router02} from "../interfaces/IUniswapV2Router02.sol";

contract UniswapV2SwapAmountsTest is Test {
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant UNISWAP_V2_ROUTER_02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant MKR = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;

    IWETH private constant weth = IWETH(WETH);
    IERC20 private constant dai = IERC20(DAI);
    IERC20 private constant mkr = IERC20(MKR);
    IUniswapV2Router02 private constant router = IUniswapV2Router02(UNISWAP_V2_ROUTER_02);

    function test_getAmountsOut() public view {
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = DAI;
        path[2] = MKR;

        uint256 amountIn = 1e18;
        uint256[] memory amounts = router.getAmountsOut(amountIn, path);
        console2.log("WETH", amounts[0]);
        console2.log("DAI", amounts[1]);
        console2.log("MKR", amounts[2]);
    }

    function test_getAmountsIn() public view {
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = DAI;
        path[2] = MKR;

        uint256 amountOut = 1e15; // 0.001 MKR
        uint256[] memory amounts = router.getAmountsIn(amountOut, path);
        console2.log("WETH", amounts[0]);
        console2.log("DAI", amounts[1]);
        console2.log("MKR", amounts[2]);
    }

    // SEND EXACT 2k DAI expect minimum 1 MKR out
    function testSwapExactInMinOut() public {
        // Test setup
        address[] memory path = new address[](3);
        path[0] = DAI;
        path[1] = WETH;
        path[2] = MKR;
        uint amountIn = 2000 * 10 ** IERC20(DAI).decimals(); // give the user 10k DAI
        uint amountOut = 1;

        console2.log("amountIn", amountIn);

        address user = makeAddr("user");
        deal(user, 1e18); // give the user 1 ETH for gas

        deal(DAI, user, amountIn);

        vm.startPrank(user);
        dai.approve(address(router), type(uint256).max);
        router.swapExactTokensForTokens(amountIn, amountOut, path, user, block.timestamp);

        vm.stopPrank();

        console2.log("DAI balance", dai.balanceOf(user));
        console2.log("WETH balance", weth.balanceOf(user));
        console2.log("MKR balance", mkr.balanceOf(user));
        
        assertGe(mkr.balanceOf(user), amountOut, "MKR balance of user");
    }
}
