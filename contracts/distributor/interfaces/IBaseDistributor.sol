// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../../IEquationContractsV1Minimum.sol";
import "../../core/interfaces/IMarketDescriptor.sol";

interface IBaseDistributor {
    struct CollectReferralTokenRewardParameter {
        uint16 referralToken;
        uint16 rewardType;
        uint200 amount;
    }

    /// @notice Set whether the address of the reward collector is enabled or disabled
    /// @param collector Address to set
    /// @param enabled Whether the address is enabled or disabled
    function setCollector(address collector, bool enabled) external;

    function EFC() external view returns (IEFC);

    function signer() external view returns (address);

    function collectors(address collector) external view returns (bool);

    function nonces(address account) external view returns (uint32);

    function collectedRewards(address account, uint16 rewardType) external view returns (uint200);

    function collectedReferralRewards(uint16 referralToken, uint16 rewardType) external view returns (uint200);

    function collectedMarketRewards(
        address account,
        IMarketDescriptor market,
        uint16 rewardType
    ) external view returns (uint200);
}
