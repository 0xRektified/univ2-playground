//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IUniswapV3Pool} from "../../interfaces/uniswapV3/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "../../interfaces/uniswapV3/IUniswapV3Factory.sol";
import {FullMath} from "../../src/uniswapV3/libraries/FullMath.sol";
// import {UniswapV3Pool} from '@uniswap/v3-core/contracts/UniswapV3Pool.sol';
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract UniswapV3FactoryTest is Test {
    address constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    IUniswapV3Factory private factory= IUniswapV3Factory(UNISWAP_V3_FACTORY);
    address constant UNISWAP_V3_POOL_DAI_USDC_100 = 0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;


    MockToken tokenA;
    MockToken tokenB;
    
    function setUp() public {
        tokenA = new MockToken('A', 'A');
        tokenB = new MockToken('B', 'B');
    }   

    function test_getPool() public view {
       address pool = factory.getPool(DAI, USDC, 100);
       assertEq(pool, UNISWAP_V3_POOL_DAI_USDC_100);
    }

    function test_createPool() public {
        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        uint24 fee = 100;
        address pool = factory.createPool(token0, token1, fee);
        assertEq(IUniswapV3Pool(pool).token0(), token0);
        assertEq(IUniswapV3Pool(pool).token1(), token1);
        assertEq(IUniswapV3Pool(pool).fee(), fee);
    } 
}