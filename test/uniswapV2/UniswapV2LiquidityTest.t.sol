// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IWETH} from "../../interfaces/IWETH.sol";
import {IUniswapV2Router02} from "../../interfaces/IUniswapV2Router02.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUniswapV2Factory} from "../../interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "../../interfaces/IUniswapV2Pair.sol";

contract UniswapV2AddLiquidityTest is Test {
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant UNISWAP_V2_ROUTER_02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    IWETH private constant weth = IWETH(WETH);
    IERC20 private constant dai = IERC20(DAI);
    address constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    IUniswapV2Factory private constant factory = IUniswapV2Factory(UNISWAP_V2_FACTORY);
    address user = makeAddr("user");
    IUniswapV2Router02 private constant router = IUniswapV2Router02(UNISWAP_V2_ROUTER_02);

    function setUp() public {
        // Give 100 ETH to the user
        deal(user, 100 * 1e18);
        vm.startPrank(user);
        weth.deposit{value: 99 * 1e18}();
        weth.approve(address(router), type(uint256).max);
        deal(DAI, user, 1000000 * 1e18);
        dai.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    function test_addAndRemoveLiquidity() public {
        // Exercise - Add Liquidity to DAI / WETH pool
        // Write your code here
        // Don't change any other code

        vm.startPrank(user);
        console2.log("user", user);

        console2.log("WETH balance", weth.balanceOf(user));
        console2.log("DAI balance", dai.balanceOf(user));
        (uint256 amountA, uint256 amountB, uint256 liquidity) =
            router.addLiquidity(WETH, DAI, 1 * 1e18, 2600 * 1e18, 1 * 1e18, 2500 * 1e18, user, block.timestamp);
        address pair = factory.getPair(WETH, DAI);
        console2.log("pair", pair);
        console2.log("amountA", amountA);
        console2.log("amountB", amountB);
        console2.log("liquidity", liquidity);
        vm.stopPrank();

        assertGt(IUniswapV2Pair(pair).balanceOf(user), 0, "LP > 0");

        vm.startPrank(user);
        IERC20 LPtoken = IERC20(pair);
        LPtoken.approve(address(router), type(uint256).max);
        (uint256 amountAReturned, uint256 amountBReturned) =
            router.removeLiquidity(WETH, DAI, liquidity, 99 * 1e16, 2500 * 1e18, user, block.timestamp);
        console2.log("amountA", amountAReturned);
        console2.log("amountB", amountBReturned);
        vm.stopPrank();

        assertEq(IUniswapV2Pair(pair).balanceOf(user), 0, "LP = 0");
    }
}
