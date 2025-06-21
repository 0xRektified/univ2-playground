pragma solidity >=0.8.20;

interface IUniswapV2FlashSwap {
    function flashSwap(address token, uint256 amount) external;
}
