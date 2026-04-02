// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";

import {PoolKey} from "../../src/22-uniswap-v4/interfaces/IUniswapV4.sol";
import {UniswapV4Base} from "./UniswapV4Base.t.sol";

contract UniswapV4UniversalRouterExampleTest is UniswapV4Base {
    function testEncodeExactInputSingleBuildsSingleRouterCommand() public view {
        PoolKey memory key = _poolKey();
        (bytes memory commands, bytes[] memory inputs) =
            routerExample.encodeExactInputSingle(key, false, 1 ether, 1, bytes(""));

        assertEq(commands.length, 1);
        assertEq(uint8(commands[0]), 0x10);
        assertEq(inputs.length, 1);
        assertGt(inputs[0].length, 0);
    }

    function testRouterSwapExactInputSingleTransfersOutput() public {
        (PoolKey memory key,) = _seedCorePool();

        address trader = makeAddr("router-trader");
        address recipient = makeAddr("router-recipient");
        deal(WETH, trader, 1 ether);

        vm.startPrank(trader);
        IERC20(WETH).approve(address(routerExample), type(uint256).max);
        uint256 amountOut = routerExample.swapExactInputSingle(
            key, false, 0.1 ether, 0, block.timestamp + 1 hours, recipient, bytes("")
        );
        vm.stopPrank();

        assertGt(amountOut, 0);
        assertEq(IERC20(DAI).balanceOf(recipient), amountOut);
    }
}
