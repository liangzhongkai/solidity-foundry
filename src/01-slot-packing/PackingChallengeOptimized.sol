// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract PackingChallengeOptimized {
    // 优化后的顺序：uint128 a, uint128 c, uint256 b
    // 这将占用2个slot：slot0(a+c), slot1(b)
    uint128 public a = 1;
    uint128 public c = 3;
    uint256 public b = 2;
}
