// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {ERC1155Bingo} from "../../src/16-erc1155-bingo/ERC1155Bingo.sol";

contract ERC1155BingoTest is Test {
    ERC1155Bingo internal bingo;

    address internal alice = address(0xA1);
    address internal bob = address(0xB2);
    uint256 internal constant BLOCKS_BETWEEN_DRAWS = 5;

    function setUp() public {
        bingo = new ERC1155Bingo();
    }

    function test_createGame() public {
        uint256 id = bingo.createGame(BLOCKS_BETWEEN_DRAWS);
        assertEq(id, 1);
        assertEq(bingo.gameCount(), 1);

        (uint256 n,,,,) = bingo.games(1);
        assertEq(n, BLOCKS_BETWEEN_DRAWS);
    }

    function test_joinGame_receivesGridAndTokens() public {
        bingo.createGame(BLOCKS_BETWEEN_DRAWS);

        vm.prank(alice);
        bingo.joinGame(1);

        uint8[25] memory grid = bingo.getGrid(1, alice);
        uint256 seen = 0;
        for (uint256 i = 0; i < 25; i++) {
            assertGe(grid[i], 1);
            assertLe(grid[i], 25);
            seen |= (1 << (grid[i] - 1));
        }
        assertEq(seen, (1 << 25) - 1, "grid must contain 1-25 exactly once");

        for (uint256 id = 1; id <= 25; id++) {
            assertEq(bingo.balanceOf(alice, id), 1);
        }
    }

    function test_joinGame_alreadyJoined_reverts() public {
        bingo.createGame(BLOCKS_BETWEEN_DRAWS);
        vm.startPrank(alice);
        bingo.joinGame(1);
        vm.expectRevert(ERC1155Bingo.AlreadyJoined.selector);
        bingo.joinGame(1);
    }

    function test_joinGame_finished_reverts() public {
        bingo.createGame(1);
        vm.prank(alice);
        bingo.joinGame(1);
        for (uint256 i = 0; i < 25; i++) {
            vm.roll(block.number + 1);
            bingo.draw(1);
            (,,, address _w, bool fin) = bingo.games(1);
            if (fin) break;
        }
        (,,, address _winner, bool finished) = bingo.games(1);
        assertTrue(finished);

        vm.prank(bob);
        vm.expectRevert(ERC1155Bingo.GameFinished.selector);
        bingo.joinGame(1);
    }

    function test_draw_triggersAfterNBlocks() public {
        bingo.createGame(BLOCKS_BETWEEN_DRAWS);
        vm.prank(alice);
        bingo.joinGame(1);

        // First draw can happen immediately (blockAtLastDraw was 0)
        bingo.draw(1);
        (, uint64 blockAtLastDraw,,,) = bingo.games(1);
        assertEq(uint256(blockAtLastDraw), block.number);

        // Second draw needs n more blocks
        vm.expectRevert(ERC1155Bingo.NotEnoughBlocks.selector);
        bingo.draw(1);

        vm.roll(block.number + BLOCKS_BETWEEN_DRAWS);
        bingo.draw(1);
    }

    function test_draw_marksPlayerGrid() public {
        bingo.createGame(BLOCKS_BETWEEN_DRAWS);
        vm.prank(alice);
        bingo.joinGame(1);

        uint8[25] memory grid = bingo.getGrid(1, alice);
        uint8 firstInRow0 = grid[0];

        vm.roll(block.number + BLOCKS_BETWEEN_DRAWS);
        bingo.draw(1);

        uint256 marked = bingo.getMarkedBitmap(1, alice);
        bool found = false;
        for (uint256 i = 0; i < 25; i++) {
            if (grid[i] == firstInRow0) {
                assertTrue((marked & (1 << i)) != 0);
                found = true;
                break;
            }
        }
        assertTrue(found);
    }

    function test_draw_gameNotFound_reverts() public {
        vm.expectRevert(ERC1155Bingo.GameNotFound.selector);
        bingo.draw(999);
    }

    function test_draw_noPlayers_reverts() public {
        bingo.createGame(BLOCKS_BETWEEN_DRAWS);
        vm.roll(block.number + BLOCKS_BETWEEN_DRAWS);
        vm.expectRevert(ERC1155Bingo.NoPlayers.selector);
        bingo.draw(1);
    }

    function test_bingo_fiveInRowWins() public {
        bingo.createGame(1);
        vm.prank(alice);
        bingo.joinGame(1);

        for (uint256 i = 0; i < 25; i++) {
            vm.roll(block.number + 1);
            bingo.draw(1);
            (,,, address winner, bool finished) = bingo.games(1);
            if (finished) {
                assertEq(winner, alice);
                return;
            }
        }
        (,,, address _w, bool fin) = bingo.games(1);
        assertTrue(fin, "game should end with a winner after 25 draws");
    }

    function test_draw_secondCallNeedsNMoreBlocks() public {
        bingo.createGame(BLOCKS_BETWEEN_DRAWS);
        vm.prank(alice);
        bingo.joinGame(1);

        vm.roll(block.number + BLOCKS_BETWEEN_DRAWS);
        bingo.draw(1);

        vm.expectRevert(ERC1155Bingo.NotEnoughBlocks.selector);
        bingo.draw(1);

        vm.roll(block.number + BLOCKS_BETWEEN_DRAWS);
        bingo.draw(1);
    }
}
