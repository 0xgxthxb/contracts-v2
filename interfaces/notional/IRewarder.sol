// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.7.0;

interface IRewarder {
    function claimRewards(
        address account,
        uint256 nTokenBalanceBefore,
        uint256 nTokenBalanceAfter,
        int256  netNTokenSupplyChange,
        uint256 NOTETokensClaimed
    ) external;
}