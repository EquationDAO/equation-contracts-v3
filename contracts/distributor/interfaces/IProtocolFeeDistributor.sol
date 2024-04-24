// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./IBaseDistributor.sol";

interface IProtocolFeeDistributor is IBaseDistributor {
    /// @notice Emitted when the campaign rate is changed
    /// @param newRate The new campaign rate,
    /// denominated in ten thousandths of a bip (i.e. 1e-8)
    event CampaignRateChanged(uint32 newRate);
    /// @notice Emitted when the campaign amount is changed
    /// @param sender The sender of the campaign amount change
    /// @param amount The delta campaign amount
    event CampaignAmountChanged(address indexed sender, uint256 amount);
    /// @notice Emitted when the campaign reward is collected
    /// @param account The account that collected the reward
    /// @param nonce The nonce of the account
    /// @param referralToken The referral token, 0 if not a referral
    /// @param rewardType The type of the reward
    /// @param amount The amount of the reward
    /// @param receiver The address that received the reward
    event CampaignRewardCollected(
        address indexed account,
        uint32 nonce,
        uint16 referralToken,
        uint16 rewardType,
        uint200 amount,
        address receiver
    );
    /// @notice Event emitted when the reward type description is set
    event RewardTypeDescriptionSet(uint16 indexed rewardType, string description);

    /// @notice Invalid campaign rate
    error InvalidCampaignRate(uint32 rate);
    /// @notice Insufficient balance
    error InsufficientBalance(uint256 balance, uint256 requiredBalance);

    /// @notice The campaign reward rate,
    /// denominated in ten thousandths of a bip (i.e. 1e-8)
    function campaignRate() external view returns (uint32);

    /// @notice Set the campaign reward rate
    /// @param newRate The new campaign rate,
    /// denominated in ten thousandths of a bip (i.e. 1e-8)
    function setCampaignRate(uint32 newRate) external;

    /// @notice Get the reward type description
    function rewardTypeDescriptions(uint16 rewardType) external view returns (string memory);

    /// @notice Set the reward type description
    /// @param rewardType The reward type to set
    /// @param description The description to set
    function setRewardType(uint16 rewardType, string calldata description) external;

    /// @notice Deposit the protocol fee
    function deposit() external;

    /// @notice Collect the campaign reward
    /// @param account The account that collected the reward for
    /// @param nonce The nonce of the account
    /// @param rewardType The type of the reward
    /// @param amount The total amount of the reward
    /// @param signature The signature of the parameters to verify
    /// @param receiver The address that received the reward
    function collectCampaignReward(
        address account,
        uint32 nonce,
        uint16 rewardType,
        uint200 amount,
        bytes calldata signature,
        address receiver
    ) external;

    /// @notice Collect the referrals campaign reward
    /// @param account The account that collected the reward for
    /// @param nonce The nonce of the account
    /// @param parameters The parameters of the reward
    /// @param signature The signature of the parameters to verify
    /// @param receiver The address that received the reward
    function collectReferralCampaignRewards(
        address account,
        uint32 nonce,
        CollectReferralTokenRewardParameter[] calldata parameters,
        bytes calldata signature,
        address receiver
    ) external;
}
