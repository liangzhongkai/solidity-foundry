// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract PackingChallenge {
    // 第一种顺序：uint128 a, uint256 b, uint128 c
    // 这将占用3个slot：slot0(a), slot1(b), slot2(c)
    uint128 public a = 1;
    uint256 public b = 2;
    uint128 public c = 3;
}
