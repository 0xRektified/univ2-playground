// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {UniswapV3Flash} from "../../src/uniswapV3/UniswapV3Flash.sol";

contract UniswapV3FlashTest is Test {
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant UNISWAP_V3_POOL_DAI_WETH_3000 = 0xC2e9F25Be6257c210d7Adf0D4Cd6E3E881ba25f8;
    IERC20 private constant weth = IERC20(WETH);
    IERC20 private constant dai = IERC20(DAI);
    UniswapV3Flash private uni;

    function setUp() public {
        uni = new UniswapV3Flash(UNISWAP_V3_POOL_DAI_WETH_3000);

        deal(DAI, address(this), 1e3 * 1e18);
        dai.approve(address(uni), type(uint256).max);
    }

    function test_flash() public {
        uint256 daiBefore = dai.balanceOf(address(this));
        uni.flash(1e3 * 1e18, 0);
        uint256 daiAfter = dai.balanceOf(address(this));

        uint256 fee = daiBefore - daiAfter;
        console2.log("DAI fee", fee);
    }
}
