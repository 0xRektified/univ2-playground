// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IUniswapV2Pair} from
    "../interfaces/IUniswapV2Pair.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IUniswapV2Router02} from
    "../interfaces/IUniswapV2Router02.sol";

contract UniswapV2Arb is Test{
    address currentPair;
    struct SwapParams {
        address router0;
        address router1;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minProfit;
    }

    // Test setup
    // User get WETH approve router to spend it
    // Sell WETH for DAI
    // SO ETH is cheaper on Uniswap than Sushiswap
    function swap(SwapParams calldata params) external {
        // transfer 1000 DAI to this contract
        IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        uint256 amountOut = 0.2 ether ; // optimize that
        address[] memory path = new address[](2);
        path[0] = params.tokenIn; // DAI
        path[1] = params.tokenOut; // WETH

        // approve router to use dai
        IERC20(params.tokenIn).approve(params.router0, params.amountIn);// approve router to spend dai

        // Swap DAI for at least 0.2 WETH
        uint[] memory amounts = IUniswapV2Router02(params.router0).swapExactTokensForTokens(
            params.amountIn,
            amountOut,
            path,
            address(this),
            block.timestamp
        );
        console2.log("amounts", amounts[1]);

        // TOTAL OUT is the 1000DAI + 1
        uint256 totalOut = params.amountIn + params.minProfit;

        // PATH is WETH in and DAI OUT
        path[0] = params.tokenOut;
        path[1] = params.tokenIn;

        IERC20(params.tokenOut).approve(params.router1, amounts[1]);// approve router to spend dai

        // Send Exact amount of WETH for totalOut DAI to user
         uint[] memory amounts2 = IUniswapV2Router02(params.router1).swapExactTokensForTokens(
            amounts[1],
            totalOut,
            path,
            msg.sender,
            block.timestamp
        );
        require(amounts2[1] >= params.amountIn + params.minProfit, "Profit too low");
    }

    function flashSwap(address pair, bool isToken0, SwapParams calldata params) external {
        // If it's token0 then the amount we want to borrow out of the pool is amount0Out
        address token = isToken0 ? IUniswapV2Pair(pair).token0() : IUniswapV2Pair(pair).token1();
        (uint256 amount0Out, uint256 amount1Out) =
        isToken0 ?
            (params.amountIn, uint256(0)) :
            (uint256(0), params.amountIn);

        // 2. Encode token and msg.sender as bytes
        bytes memory data = abi.encode( msg.sender, params);
        currentPair = pair;
        // 3. Call pair.swap
        IUniswapV2Pair(pair).swap(
            amount0Out,
            amount1Out,
            address(this),
            data
        );
        // Log Contract balance in DAI
        uint256 balance = IERC20(params.tokenOut).balanceOf(address(this));
        console2.log("balance", balance);
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {

        // 1. Require msg.sender is pair contract
        require(msg.sender == address(currentPair), "Uniswap V2: INVALID_TO");

        // 2. Require sender is this contract
        require(sender == address(this), "Uniswap V2: INVALID_TO");

        // 3. Decode token and caller from data
        (address caller, SwapParams memory params) = abi.decode(data, (address, SwapParams));


        // transfer 1000 DAI to this contract
        uint256 amountOut = 0.2 ether ; // optimize that
        address[] memory path = new address[](2);
        path[0] = params.tokenIn; // DAI
        path[1] = params.tokenOut; // WETH

        // approve router to use dai
        IERC20(params.tokenIn).approve(params.router0, params.amountIn);// approve router to spend dai

        // Swap DAI for at least 0.2 WETH
        uint[] memory amounts = IUniswapV2Router02(params.router0).swapExactTokensForTokens(
            params.amountIn,
            amountOut,
            path,
            address(this),
            block.timestamp
        );
        console2.log("amounts", amounts[1]);

        // PATH is WETH in and DAI OUT
        address[] memory path2 = new address[](2);
        path2[0] = params.tokenOut;
        path2[1] = params.tokenIn;

        IERC20(params.tokenOut).approve(params.router1, amounts[1]);// approve router to spend dai

        // Send Profit to user
         uint[] memory amounts2 = IUniswapV2Router02(params.router1).swapExactTokensForTokens(
            amounts[1],
            params.minProfit,
            path2,
            address(this),
            block.timestamp
        );

        // 5. Calculate flash swap fee and amount to repay
        uint256 fee = (params.amountIn * 3) / 997 + 1; // 1 to round up
        uint256 amountToRepay = params.amountIn + fee;
        require( amounts2[1] >= amountToRepay , "Not enough profit");
        uint256 profit = amounts2[1] - amountToRepay;

        require(profit >= params.minProfit, "Profit too low");


        IERC20(params.tokenIn).transfer(caller , profit);
        IERC20(params.tokenIn).transfer(address(currentPair), amountToRepay);
    }
}