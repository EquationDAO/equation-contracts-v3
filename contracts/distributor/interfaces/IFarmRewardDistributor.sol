// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./IBaseDistributor.sol";

interface IFarmRewardDistributor is IBaseDistributor {
    /// @notice Collect the farm reward
    /// @param account The account that collected the reward for
    /// @param nonce The nonce of the account
    /// @param lockupPeriod The lockup period of the reward
    /// @param rewardType The type of the reward
    /// @param amount The total amount of the reward
    /// @param signature The signature of the parameters to verify
    /// @param receiver The address that received the reward
    function collectReward(
        address account,
        uint32 nonce,
        uint16 lockupPeriod,
        uint16 rewardType,
        uint200 amount,
        bytes calldata signature,
        address receiver
    ) external;

    /// @notice Collect the referrals farm reward
    /// @param account The account that collected the reward for
    /// @param nonce The nonce of the account
    /// @param lockupPeriod The lockup period of the reward
    /// @param parameters The parameters of the reward
    /// @param signature The signature of the parameters to verify
    /// @param receiver The address that received the reward
    function collectReferralRewards(
        address account,
        uint32 nonce,
        uint16 lockupPeriod,
        CollectReferralTokenRewardParameter[] calldata parameters,
        bytes calldata signature,
        address receiver
    ) external;

    /// @notice Collect the market farm reward
    /// @param account The account that collected the reward for
    /// @param nonce The nonce of the account
    /// @param lockupPeriod The lockup period of the reward
    /// @param rewardType The type of the reward
    /// @param market The market of the reward
    /// @param amount The total amount of the reward
    /// @param signature The signature of the parameters to verify
    /// @param receiver The address that received the reward
    function collectMarketReward(
        address account,
        uint32 nonce,
        uint16 lockupPeriod,
        uint16 rewardType,
        IMarketDescriptor market,
        uint200 amount,
        bytes calldata signature,
        address receiver
    ) external;
}
