// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {IUniswapV2Pair} from
    "../interfaces/IUniswapV2Pair.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Test, console2} from "forge-std/Test.sol";

contract UniswapV2Arb2 {
    struct FlashSwapData {
        address caller;
        address pair0;
        address pair1;
        bool isZeroForOne;
        uint256 amountIn;
        uint256 minProfit;
    }
    address currentPair;


    /**
        @param pair0 The pair to borrow from
        @param pair1 The pair to arbitrage
        @param isZeroForOne True if flash swap is token0 in and token1 out
        @param amountIn Amount in to borrow for flash swap
        @param minProfit The minimum profit to make
    */
    function flashSwap(
        address pair0,
        address pair1,
        bool isZeroForOne,
        uint256 amountIn,
        uint256 minProfit
    ) external {
        currentPair = pair0;

        //Get reserve for token0 so we know how much we get out with the amount put in
        (uint112 pair0Reserve0, uint112 pair0Reserve1,) = IUniswapV2Pair(pair0).getReserves();


        // IF we send token0 amount should be in token1 so we need to
        // order nominator and denominator accordingly
        uint256 amountOut = isZeroForOne ?
        getAmountOut(amountIn, pair0Reserve0, pair0Reserve1) :
        getAmountOut(amountIn, pair0Reserve1, pair0Reserve0);

        // Now we get the correct amount out regarding the token sent
        (uint256 amount0Out, uint256 amount1Out ) =
        isZeroForOne ?
        (uint256(0), amountOut) :
        (amountOut, uint256(0));


        // Setup up data needed later for the arbitrage
        bytes memory data = abi.encode(FlashSwapData({
                caller: msg.sender,
                pair0: pair0,
                pair1: pair1,
                isZeroForOne: isZeroForOne,
                amountIn: amountIn,
                minProfit: minProfit
            }));
       
       // Borrow amountIn from pair0
        IUniswapV2Pair(pair0).swap(
            amount0Out,
            amount1Out,
            address(this),
            data
        );
    }    

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        require(msg.sender == address(currentPair), "Uniswap V2: INVALID_TO");

        require(sender == address(this), "UniswapV2Arb2: FORBIDDEN");
        FlashSwapData memory flashSwapData = abi.decode(data, (FlashSwapData));
        address token0 = IUniswapV2Pair(flashSwapData.pair0).token0();
        address token1 = IUniswapV2Pair(flashSwapData.pair0).token1();

        //require(msg.sender == flashSwapData.caller, "UniswapV2Arb2: NOT GOOD CHECK THAT");


        (uint256 amount, address tokenForSwap, address tokenToRepay) = amount0 > 0 ?
        (amount0, token0, token1) :
        (amount1, token1, token0);
        
        // Here we transfer the WETH to the pool for the swap
        IERC20(tokenForSwap).transfer(flashSwapData.pair1, amount);


        // Now we need to know how much out we want based on this amount in
        (uint112 pair0Reserve0, uint112 pair0Reserve1,) = IUniswapV2Pair(flashSwapData.pair1).getReserves();
        // IF we send token1 amount should be in token0
        // This should be the opposite order as in the first swap
        uint256 amountOut = flashSwapData.isZeroForOne ?
        getAmountOut(amount, pair0Reserve1, pair0Reserve0) :
        getAmountOut(amount, pair0Reserve0, pair0Reserve1);

        // Here we set the swap parameters in the correct order
        // To request the right amount from the pool
        (uint256 amount0Out, uint256 amount1Out) = flashSwapData.isZeroForOne ?
        ( amountOut, uint256(0)) :
        (uint256(0), amountOut);

        // Here we execture the arbitrage
        IUniswapV2Pair(flashSwapData.pair1).swap(
            amount0Out,
            amount1Out,
            address(this),
            ""
        );

        // here we calculate the fee to repay
        uint256 feeToRepay = amount + (amount * 3) / 997 + 1; // 1 to round up

        // Now we need to repay the flash swap + fees
        IERC20(tokenToRepay).transfer(flashSwapData.pair0,  flashSwapData.amountIn);
        
        // Here we send back the profit to the user
        uint256 profit = IERC20(tokenToRepay).balanceOf(address(this));
        require(profit >= flashSwapData.minProfit, "Profit too low");
        IERC20(tokenToRepay).transfer(flashSwapData.caller, profit);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
}