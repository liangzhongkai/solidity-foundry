// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";

import {UniswapV3SwapExample} from "../../src/21-uniswap-v3/UniswapV3SwapExample.sol";

interface IWETH {
    function deposit() external payable;
}

/// @notice Fork tests for `exactInputSingle`. Demonstrates fee tier selection and slippage floor usage.
contract UniswapV3SwapExampleTest is Test {
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    uint24 internal constant FEE_030 = 3000;

    uint256 internal constant SWAP_IN = 1 ether;

    UniswapV3SwapExample internal example;
    IERC20 internal weth;
    IERC20 internal dai;
    address internal recipient;

    function setUp() public {
        example = new UniswapV3SwapExample();
        weth = IERC20(WETH);
        dai = IERC20(DAI);
        recipient = makeAddr("recipient");

        if (example.SWAP_ROUTER().code.length == 0 || WETH.code.length == 0) {
            vm.skip(true);
        }
    }

    /// @dev Production pattern: combine an off-chain quote with `amountOutMinimum`; here we only assert the swap succeeds with a loose floor.
    function testSwapExactInputSingleWethToDai() public {
        address trader = makeAddr("trader");
        vm.deal(trader, 2 ether);
        vm.startPrank(trader);
        IWETH(WETH).deposit{value: SWAP_IN}();
        weth.approve(address(example), SWAP_IN);

        uint256 beforeOut = dai.balanceOf(recipient);
        uint256 amountOut =
            example.swapExactInputSingle(WETH, DAI, FEE_030, SWAP_IN, 1, 0, block.timestamp + 1 hours, recipient);
        vm.stopPrank();

        assertGt(amountOut, 0);
        assertEq(dai.balanceOf(recipient) - beforeOut, amountOut);
    }

    function testSwapRevertsForZeroRecipient() public {
        vm.expectRevert(UniswapV3SwapExample.ZeroAddress.selector);
        example.swapExactInputSingle(WETH, DAI, FEE_030, 1, 1, 0, block.timestamp + 1, address(0));
    }

    /// @dev Wrong fee tier => no pool => router reverts (teaches validating the pool exists before swapping).
    function testSwapRevertsForMismatchedFeeTier() public {
        address trader = makeAddr("trader");
        vm.deal(trader, 1 ether);
        vm.startPrank(trader);
        IWETH(WETH).deposit{value: 0.1 ether}();
        weth.approve(address(example), 0.1 ether);

        uint24 nonexistentFee = 1337;
        vm.expectRevert();
        example.swapExactInputSingle(WETH, DAI, nonexistentFee, 0.1 ether, 1, 0, block.timestamp + 1 hours, recipient);
        vm.stopPrank();
    }
}
