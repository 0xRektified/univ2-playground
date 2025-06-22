// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IUniswapV2Router02} from "../interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "../interfaces/IUniswapV2Pair.sol";
import {UniswapV2Twap} from "../src/UniswapV2Twap.sol";
import {IUniswapV2Factory} from "../interfaces/IUniswapV2Factory.sol";

contract UniswapV2TwapTest is Test {
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant UNISWAP_V2_ROUTER_02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    IERC20 private constant weth = IERC20(WETH);
    IUniswapV2Router02 private constant router = IUniswapV2Router02(UNISWAP_V2_ROUTER_02);
    IUniswapV2Factory private constant factory = IUniswapV2Factory(UNISWAP_V2_FACTORY);
    IUniswapV2Pair private pair;

    uint256 private constant MIN_WAIT = 300;

    UniswapV2Twap private twap;

    function setUp() public {
        pair = IUniswapV2Pair(factory.getPair(WETH, DAI));
        twap = new UniswapV2Twap(address(pair));
    }

    function getSpot() internal view returns (uint256) {
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        // DAI / WETH
        return uint256(reserve0) * 1e18 / uint256(reserve1);
    }

    function swap() internal {
        deal(WETH, address(this), 100 * 1e18);
        weth.approve(address(router), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = DAI;

        // Input token amount and all subsequent output token amounts
        uint256[] memory amounts = router.swapExactTokensForTokens({
            amountIn: 100 * 1e18,
            amountOutMin: 1,
            path: path,
            to: address(this),
            deadline: block.timestamp
        });
        console2.log("amount[0]", amounts[0]);
        console2.log("amount[1]", amounts[1]);
    }

    function test_twap_same_price() public {
        skip(MIN_WAIT + 1);
        twap.update();

        uint256 twap0 = twap.consult(WETH, 1e18);

        skip(MIN_WAIT + 1);
        twap.update();

        uint256 twap1 = twap.consult(WETH, 1e18);

        assertApproxEqAbs(twap0, twap1, 1, "ETH TWAP");
    }

    function test_twap_close_to_last_spot() public {
        // Update TWAP
        skip(MIN_WAIT + 1);
        twap.update();

        // Get TWAP
        uint256 twap0 = twap.consult(WETH, 1e18);

        // Swap
        swap();
        uint256 spot = getSpot();
        console2.log("ETH spot price", spot);

        // Update TWAP
        skip(MIN_WAIT + 1);
        twap.update();

        // Get TWAP
        uint256 twap1 = twap.consult(WETH, 1e18);

        console2.log("twap0", twap0);
        console2.log("twap1", twap1);

        // Check TWAP is close to last spot
        assertLt(twap1, twap0, "twap1 >= twap0");
        assertGe(twap1, spot, "twap1 < spot");
    }
}
