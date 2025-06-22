// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IUniswapV2Pair} from "../interfaces/IUniswapV2Pair.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Test, console2} from "forge-std/Test.sol";

contract UniswapV2Arb3 {
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
     * @param pair0 The pair to borrow from
     *     @param pair1 The pair to arbitrage
     *     @param isZeroForOne True if flash swap is token0 in and token1 out
     *     @param amountIn Amount in to borrow for flash swap
     *     @param minProfit The minimum profit to make
     */
    function flashSwap(address pair0, address pair1, bool isZeroForOne, uint256 amountIn, uint256 minProfit) external {
        currentPair = pair0;

        //Get reserve for token0 so we know how much we get out with the amount put in
        (uint112 pair0Reserve0, uint112 pair0Reserve1,) = IUniswapV2Pair(pair0).getReserves();

        // IF we send token0 amount should be in token1 so we need to
        // order nominator and denominator accordingly
        uint256 amountOut = isZeroForOne
            ? getAmountOut(amountIn, pair0Reserve0, pair0Reserve1)
            : getAmountOut(amountIn, pair0Reserve1, pair0Reserve0);

        // Now we get the correct amount out regarding the token sent
        (uint256 amount0Out, uint256 amount1Out) = isZeroForOne ? (uint256(0), amountOut) : (amountOut, uint256(0));

        // Setup up data needed later for the arbitrage
        bytes memory data = abi.encode(
            FlashSwapData({
                caller: msg.sender,
                pair0: pair0,
                pair1: pair1,
                isZeroForOne: isZeroForOne,
                amountIn: amountIn,
                minProfit: minProfit
            })
        );

        // Borrow amountIn from pair0
        IUniswapV2Pair(pair0).swap(amount0Out, amount1Out, address(this), data);
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        require(msg.sender == address(currentPair), "Uniswap V2: INVALID_TO");

        require(sender == address(this), "UniswapV2Arb2: FORBIDDEN");
        FlashSwapData memory flashSwapData = abi.decode(data, (FlashSwapData));
        address token0 = IUniswapV2Pair(flashSwapData.pair0).token0();
        address token1 = IUniswapV2Pair(flashSwapData.pair0).token1();

        //require(msg.sender == flashSwapData.caller, "UniswapV2Arb2: NOT GOOD CHECK THAT");

        (uint256 amount, address tokenForSwap, address tokenToRepay) =
            amount0 > 0 ? (amount0, token0, token1) : (amount1, token1, token0);

        // Here we transfer the WETH to the pool for the swap
        IERC20(tokenForSwap).transfer(flashSwapData.pair1, amount);

        // Now we need to know how much out we want based on this amount in
        (uint112 pair0Reserve0, uint112 pair0Reserve1,) = IUniswapV2Pair(flashSwapData.pair1).getReserves();
        // IF we send token1 amount should be in token0
        // This should be the opposite order as in the first swap
        uint256 amountOut = flashSwapData.isZeroForOne
            ? getAmountOut(amount, pair0Reserve1, pair0Reserve0)
            : getAmountOut(amount, pair0Reserve0, pair0Reserve1);

        // Here we set the swap parameters in the correct order
        // To request the right amount from the pool
        (uint256 amount0Out, uint256 amount1Out) =
            flashSwapData.isZeroForOne ? (amountOut, uint256(0)) : (uint256(0), amountOut);

        // Here we execture the arbitrage
        IUniswapV2Pair(flashSwapData.pair1).swap(amount0Out, amount1Out, address(this), "");

        // here we calculate the fee to repay
        // TODO FEE SHOULD BE REPAYED HERE SOMETHING WRONG
        uint256 feeToRepay = amount + (amount * 3) / 997 + 1; // 1 to round up

        // Now we need to repay the flash swap + fees
        IERC20(tokenToRepay).transfer(flashSwapData.pair0, flashSwapData.amountIn);

        // Here we send back the profit to the user
        uint256 profit = IERC20(tokenToRepay).balanceOf(address(this));
        require(profit >= flashSwapData.minProfit, "Profit too low");
        IERC20(tokenToRepay).transfer(flashSwapData.caller, profit);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // THis is not optimal AT ALL, we need to compute this off chain with
    // the correct formula
    function getOptimalAmountIn(
        uint256 xA, // AMM A reserve out
        uint256 yA, // AMM A reserve in
        uint256 xB, // AMM B reserve in
        uint256 yB // AMM B reserve out
    ) public pure returns (uint256 optimalAmountIn) {
        require(xA > 0 && yA > 0 && xB > 0 && yB > 0, "Invalid reserves");
        
        console2.log("=== ANALYSIS ===");
        console2.log("xA", xA);
        console2.log("yA", yA);
        console2.log("xB", xB);
        console2.log("yB", yB);
        
        // Calculate current prices
        uint256 priceA = (xA * 1e18) / yA; // Price on AMM A (how much xA per yA)
        uint256 priceB = (yB * 1e18) / xB; // Price on AMM B (how much yB per xB)
        
        console2.log("priceA (xA/yA)", priceA);
        console2.log("priceB (yB/xB)", priceB);
        console2.log("price difference", priceA > priceB ? priceA - priceB : priceB - priceA);
        console2.log("price ratio %", priceA > priceB ? (priceA * 100) / priceB : (priceB * 100) / priceA);
        
        // Mathematical approach: equalize execution prices
        console2.log("=== SOLVING FOR EXECUTION PRICE EQUILIBRIUM ===");
        
        // Goal: y₁/(x₁ + dx) = y₂/(x₂ - dy₁) where dy₁ = getAmountOut(dx, x₁, y₁)
        // This is a more complex equation that needs iterative solving
        
        optimalAmountIn = solveOptimalUsingMarginalRates(xA, yA, xB, yB);
        console2.log("Execution price equilibrium amount:", optimalAmountIn / 1e18);
    }
    
    function solveExecutionPriceEquilibrium(
        uint256 x1, // DAI reserve AMM1
        uint256 y1, // ETH reserve AMM1  
        uint256 x2, // DAI reserve AMM2
        uint256 y2  // ETH reserve AMM2
    ) public pure returns (uint256 optimalDx) {
        // Direct mathematical solution using derivative = 0
        // For maximum profit: dP/dx = 0
        // Where P(dx) = final_dai_out - dx - flash_fee
        
        console2.log("Solving derivative equation for maximum profit");
        
        // The derivative condition leads to this equilibrium:
        // d/dx[getAmountOut(getAmountOut(dx, x1, y1), y2, x2)] = 1 + fee_rate
        // This translates to: (dy2/deth) * (deth/ddx) = 1 + 3/997
        
        // From AMM math: dy/dx = (997 * y * r) / (1000 * x + 997 * dx)^2
        // Where r = reserveOut for the AMM
        
        // Mathematical solution using the marginal rate condition
        return solveOptimalUsingMarginalRates(x1, y1, x2, y2);
    }
    
    function solveOptimalUsingMarginalRates(
        uint256 x1, // DAI reserve AMM1
        uint256 y1, // ETH reserve AMM1  
        uint256 x2, // DAI reserve AMM2
        uint256 y2  // ETH reserve AMM2
    ) internal pure returns (uint256 optimalDx) {
        // Use golden section search to find maximum profit
        // This will find the true maximum regardless of starting point
        
        uint256 smallerDaiPool = x1 < x2 ? x1 : x2;
        uint256 left = smallerDaiPool / 100;   // Start at 1% of smaller pool
        uint256 right = smallerDaiPool / 20;   // End at 5% of smaller pool
        
        console2.log("Golden section search:");
        console2.log("Search range:", left / 1e18, "to", right / 1e18);
        
        // Golden ratio
        uint256 phi = 1618; // 1.618 * 1000
        
        for (uint i = 0; i < 30; i++) {
            uint256 range = right - left;
            uint256 x1_point = left + (range * 1000) / (phi + 1000);
            uint256 x2_point = right - (range * 1000) / (phi + 1000);
            
            uint256 profit1 = calculateProfitWithFee(x1, y1, x2, y2, x1_point);
            uint256 profit2 = calculateProfitWithFee(x1, y1, x2, y2, x2_point);
            
            console2.log("Iteration", i);
            console2.log("Testing", x1_point / 1e18, "vs", x2_point / 1e18);
            console2.log("Profits", profit1 / 1e18, "vs", profit2 / 1e18);
            
            if (profit1 > profit2) {
                right = x2_point; // Maximum is in left section
            } else {
                left = x1_point;  // Maximum is in right section
            }
            
            // Convergence check
            if (right - left < 100 * 1e18) { // Within 100 DAI
                break;
            }
        }
        
        optimalDx = (left + right) / 2;
        uint256 finalProfit = calculateProfitWithFee(x1, y1, x2, y2, optimalDx);
        
        console2.log("Golden section result:");
        console2.log("Optimal dx:", optimalDx / 1e18);
        console2.log("Expected profit:", finalProfit / 1e18);
        
        return optimalDx;
    }
    
    function calculateProfitWithFee(
        uint256 x1, // DAI reserve AMM1
        uint256 y1, // ETH reserve AMM1  
        uint256 x2, // DAI reserve AMM2
        uint256 y2, // ETH reserve AMM2
        uint256 amountIn // DAI amount to borrow
    ) internal pure returns (uint256 profit) {
        if (amountIn == 0) return 0;
        
        // Step 1: Borrow amountIn DAI, swap for ETH on AMM1
        uint256 ethOut = getAmountOut(amountIn, x1, y1);
        if (ethOut == 0) return 0;
        
        // Step 2: Swap ETH for DAI on AMM2  
        uint256 daiOut = getAmountOut(ethOut, y2, x2);
        if (daiOut == 0) return 0;
        
        // Step 3: Calculate flash loan fee
        uint256 flashLoanFee = (amountIn * 3) / 997 + 1;
        uint256 totalToRepay = amountIn + flashLoanFee;
        
        // Step 4: Calculate profit
        if (daiOut > totalToRepay) {
            profit = daiOut - totalToRepay;
        } else {
            profit = 0; // Loss
        }
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}
