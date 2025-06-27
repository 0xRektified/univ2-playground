// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IV3SwapRouter} from "../../interfaces/uniswapV3/IV3SwapRouter.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IWETH} from "../../interfaces/IWETH.sol";


contract UniswapV3SwapTest is Test {
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant UNISWAP_V3_SWAP_ROUTER_02 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    IWETH private constant weth = IWETH(WETH);
    IERC20 private constant dai = IERC20(DAI);
    IERC20 private constant wbtc = IERC20(WBTC);
    uint24 private constant FEE = 3000;
    function setUp() public {
        deal(DAI, address(this), 100000 * 1e18);
        dai.approve(UNISWAP_V3_SWAP_ROUTER_02, type(uint256).max);
    }

    // Swap 1000 DAI for WETH on DAI/WETH pool with 0.3% fee
    // Send WETH from Uniswap V3 to this contract
    function testExactInputSingle() public {
        uint256 daiBalanceBefore = dai.balanceOf(address(this));
        uint256 wethBalanceBefore = weth.balanceOf(address(this));
        
        IV3SwapRouter swapRouter = IV3SwapRouter(UNISWAP_V3_SWAP_ROUTER_02);
        uint256 amountOut = swapRouter.exactInputSingle(
                IV3SwapRouter.ExactInputSingleParams({
                    tokenIn: DAI,
                    tokenOut: WETH,
                    fee: FEE,
                    recipient: address(this),
                    amountIn: 1000 * 1e18,
                    amountOutMinimum: 1,
                    sqrtPriceLimitX96: 0
                })
            );
        
        uint256 daiBalanceAfter = dai.balanceOf(address(this));
        uint256 wethBalanceAfter = weth.balanceOf(address(this));
        
        // Check DAI was spent correctly
        assertEq(daiBalanceAfter, daiBalanceBefore - 1000 * 1e18);
        
        // Check WETH was received
        assertGt(wethBalanceAfter, wethBalanceBefore);

        // Use this assertion if you want to check the actual received amount
        // rather than the reported amount
        assertEq(wethBalanceAfter - wethBalanceBefore, amountOut);
    }

    // Swap 1000 DAI for WETH and then WETH to WBTC
    // Swap  DAI/WETH pool with 0.3% fee
    // Swap WETH/WBTC pool with 0.3% fee
    // Send WBTC from Uniswap V3 to this contract
    // NOTE: WBTC has 8 decimals
    function testExactInput() public {
        bytes memory path = abi.encodePacked(DAI, FEE, WETH, FEE, WBTC);
        uint256 amountOut = IV3SwapRouter(UNISWAP_V3_SWAP_ROUTER_02).exactInput(
            IV3SwapRouter.ExactInputParams({
                path: path,
                recipient: address(this),
                amountIn: 1000 * 1e18,
                amountOutMinimum: 1
            })
        );  
        assertGt(amountOut, 0);      
        assertEq(wbtc.balanceOf(address(this)), amountOut);      
    }

    // Swap maximum of 1000DAI to obtain extactly 0.1 WETH from DAI/WETH pool with 0.3% fee
    // Send WETH from Uniswap V3 to this contract
    function testExactOutputSingle() public {
    //     ExactOutputSingleParams {
    //     address tokenIn;
    //     address tokenOut;
    //     uint24 fee;
    //     address recipient;
    //     uint256 amountOut;
    //     uint256 amountInMaximum;
    //     uint160 sqrtPriceLimitX96;
    // }
        uint256 wethBefore = weth.balanceOf(address(this));
        uint256 amountIn = IV3SwapRouter(UNISWAP_V3_SWAP_ROUTER_02).exactOutputSingle(
            IV3SwapRouter.ExactOutputSingleParams({
                tokenIn: DAI,
                tokenOut: WETH,
                fee: FEE,
                recipient: address(this),
                amountOut: 1 * 1e17,
                amountInMaximum: 1000 * 1e18,
                sqrtPriceLimitX96: 0
            })
        );  
        uint256 wethAfter = weth.balanceOf(address(this));

        assertLe(amountIn, 1000 * 1e18);      
        assertEq(wethAfter - wethBefore, 1*1e17);      
    }

    // Swap maximum of 2000 DAI to obtain extactly 0.01 WBTC
    // Send DAI to WETH on pool with 0.3% fee
    // Send WETH to WBTC on pool with 0.3% fee
    // Send WBTC from Uniswap V3 to this contract
    // NOTE WBTC has 8 decimals
    function testExactOutput() public {
        bytes memory path = abi.encodePacked(WBTC, FEE, WETH, FEE, DAI);

        uint256 amountIn = IV3SwapRouter(UNISWAP_V3_SWAP_ROUTER_02).exactOutput(
            IV3SwapRouter.ExactOutputParams({
                path: path,
                recipient: address(this),
                amountOut: 0.01 * 1e8,
                amountInMaximum: 2000 * 1e18
            })
        );

        assertLe(amountIn, 2000 * 1e18); 
        assertEq(wbtc.balanceOf(address(this)), 0.01 * 1e8);
    }
}

