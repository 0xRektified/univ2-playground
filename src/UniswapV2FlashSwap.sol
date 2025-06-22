// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {IUniswapV2Pair} from "../interfaces/IUniswapV2Pair.sol";

contract UniswapV2FlashSwap {
    IUniswapV2Pair private immutable pair;
    address private immutable token0;
    address private immutable token1;

    constructor(address _pair) {
        pair = IUniswapV2Pair(_pair);
        token0 = pair.token0();
        token1 = pair.token1();
    }

    function flashSwap(address token, uint256 amount) external {
        require(token == token0 || token == token1, "invalid token");
        (uint256 amount0Out, uint256 amount1Out) = token == token0 ? (amount, uint256(0)) : (uint256(0), amount);

        // 2. Encode token and msg.sender as bytes
        bytes memory data = abi.encode(token, msg.sender);

        // 3. Call pair.swap
        pair.swap(amount0Out, amount1Out, address(this), data);
    }

    // Uniswap V2 callback
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        // 1. Require msg.sender is pair contract
        require(msg.sender == address(pair), "Uniswap V2: INVALID_TO");

        // 2. Require sender is this contract
        require(sender == address(this), "Uniswap V2: INVALID_TO");

        // 3. Decode token and caller from data
        (address token, address caller) = abi.decode(data, (address, address));

        // 4. Determine amount borrowed (only one of them is > 0)
        uint256 amount = token0 == token ? amount0 : amount1;

        // 5. Calculate flash swap fee and amount to repay
        uint256 fee = (amount * 3) / 997 + 1; // 1 to round up
        uint256 amountToRepay = amount + fee;

        // 6. Get flash swap fee from caller
        // NOTE: Goal here is to have the contract making money and pay for the fee for the demo we have the user paying for fees
        IERC20(token).transferFrom(caller, address(this), fee);
        IERC20(token).transfer(address(pair), amountToRepay);
    }
}
