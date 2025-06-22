import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IUniswapV2Router02} from "../interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "../interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "../interfaces/IUniswapV2Pair.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {UniswapV2Arb} from "../src/UniswapV2Arb1.sol";
import {IWETH} from "../interfaces/IWETH.sol";

// Test arbitrage between Uniswap and Sushiswap
contract UniswapV2ArbTest is Test {
    address constant UNISWAP_V2_ROUTER_02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant MKR = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2; // We won't use DAI/MKR here as pool is empty
    address constant SUSHISWAP_V2_ROUTER_02 = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    IUniswapV2Factory private constant factory = IUniswapV2Factory(UNISWAP_V2_FACTORY);

    // Define router addresses
    IUniswapV2Router02 private constant uni_router = IUniswapV2Router02(UNISWAP_V2_ROUTER_02);
    IUniswapV2Router02 private constant sushi_router = IUniswapV2Router02(SUSHISWAP_V2_ROUTER_02);
    // Define token addresses
    IERC20 private constant dai = IERC20(DAI);
    IWETH private constant weth = IWETH(WETH);

    address constant user = address(11);

    UniswapV2Arb public arb;

    function setUp() public {
        arb = new UniswapV2Arb();

        // Setup: WETH cheaper on Uniswap than Sushiswap
        deal(address(this), 100 * 1e18);

        weth.deposit{value: 100 * 1e18}();
        weth.approve(address(uni_router), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = DAI;

        uni_router.swapExactTokensForTokens({
            amountIn: 100 * 1e18,
            amountOutMin: 1,
            path: path,
            to: user,
            deadline: block.timestamp
        });

        // Setup: user has DAI, approves arb to spend DAI
        deal(DAI, user, 10000 * 1e18);
        vm.prank(user);
        dai.approve(address(arb), type(uint256).max);
    }

    function test_swap() public {
        uint256 bal0 = dai.balanceOf(user);

        vm.prank(user);
        arb.swap(
            UniswapV2Arb.SwapParams({
                router0: UNISWAP_V2_ROUTER_02,
                router1: SUSHISWAP_V2_ROUTER_02,
                tokenIn: DAI,
                tokenOut: WETH,
                amountIn: 1000 * 1e18,
                minProfit: 1
            })
        );

        uint256 bal1 = dai.balanceOf(user);

        assertGt(bal1, bal0, "no profit");
        assertEq(dai.balanceOf(address(arb)), 0, "DAI balance of arb is 0");
        console2.log("profit", bal1 - bal0);
    }

    function test_flashSwap() public {
        address pair = factory.getPair(DAI, USDC);

        uint256 bal0 = dai.balanceOf(user);

        vm.prank(user);
        arb.flashSwap(
            pair,
            true,
            UniswapV2Arb.SwapParams({
                router0: UNISWAP_V2_ROUTER_02,
                router1: SUSHISWAP_V2_ROUTER_02,
                tokenIn: DAI,
                tokenOut: WETH,
                amountIn: 10000 * 1e18,
                minProfit: 1
            })
        );

        uint256 bal1 = dai.balanceOf(user);

        assertGt(bal1, bal0, "no profit");
        assertEq(dai.balanceOf(address(arb)), 0, "DAI balance of arb is 0");
        console2.log("profit", bal1 - bal0);
    }
}
