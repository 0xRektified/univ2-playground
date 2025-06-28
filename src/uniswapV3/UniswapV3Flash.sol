//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;
import {IUniswapV3Pool} from "../../interfaces/uniswapV3/IUniswapV3Pool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract UniswapV3Flash {

    struct FlashCallbackData {
        address caller;
        uint256 amount0;
        uint256 amount1;
    }
    address public immutable pool;
    address public immutable token0;
    address public immutable token1;
    address public immutable owner;

    constructor(address _pool){
        pool = _pool;
        token0 = IUniswapV3Pool(pool).token0();
        token1 = IUniswapV3Pool(pool).token1();
    }

    function flash(uint256 amount0, uint256 amount1) external {
    //     function flash(
    //     address recipient,
    //     uint256 amount0,
    //     uint256 amount1,
    //     bytes calldata data
    // )
        IUniswapV3Pool(pool).flash(address(this), amount0, amount1, abi.encode(
            FlashCallbackData({caller: msg.sender, amount0: amount0, amount1: amount1})));
    }
    
    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        require(msg.sender == pool);
        FlashCallbackData memory decodedData = abi.decode(data, (FlashCallbackData));
        
        if (fee0 > 0){
            IERC20(token0).transferFrom(decodedData.caller, pool,  fee0);
        }
        if (fee1 > 0){
            IERC20(token1).transferFrom(decodedData.caller, pool,  fee1);
        }

        if (decodedData.amount0 > 0){
            IERC20(token0).transfer(pool, decodedData.amount0 + fee0);
        }
        if (decodedData.amount1 > 0){
            IERC20(token1).transfer(pool, decodedData.amount1 + fee1);
        }
    }
}