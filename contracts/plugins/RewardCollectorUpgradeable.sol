// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.23;

import "./EquationContractsV1RewardCollectorCompatibilityUpgradeable.sol";
import "../distributor/interfaces/IFarmRewardDistributor.sol";
import "../distributor/interfaces/IProtocolFeeDistributor.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice The contract allows users to collect farm rewards and lockup and
/// burn the rewards based on the lockup period
contract RewardCollectorUpgradeable is EquationContractsV1RewardCollectorCompatibilityUpgradeable, Multicall {
    IFarmRewardDistributor public farmRewardDistributor;
    IProtocolFeeDistributor public protocolFeeDistributor;

    error InsufficientBalance(uint256 amount, uint256 requiredAmount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IRouter _routerV1,
        IFarmRewardDistributor _farmRewardDistributor,
        IFarmRewardDistributorV2 _distributorV2,
        IProtocolFeeDistributor _protocolFeeDistributor
    ) public initializer {
        __EquationContractsV1RewardCollectorCompatibilityUpgradeable_init(_routerV1, _distributorV2);

        farmRewardDistributor = _farmRewardDistributor;
        protocolFeeDistributor = _protocolFeeDistributor;
    }

    function sweepToken(IERC20 _token, uint256 _amountMinimum, address _receiver) external returns (uint256 amount) {
        amount = _token.balanceOf(address(this));
        if (amount < _amountMinimum) revert InsufficientBalance(amount, _amountMinimum);

        SafeERC20.safeTransfer(_token, _receiver, amount);
    }

    function collectFarmReward(
        uint32 _nonce,
        uint16 _lockupPeriod,
        uint16 _rewardType,
        uint200 _amount,
        bytes calldata _signature,
        address _receiver
    ) external {
        farmRewardDistributor.collectReward(
            msg.sender,
            _nonce,
            _lockupPeriod,
            _rewardType,
            _amount,
            _signature,
            _receiver
        );
    }

    function collectFarmReferralRewards(
        uint32 _nonce,
        uint16 _lockupPeriod,
        IFarmRewardDistributor.CollectReferralTokenRewardParameter[] calldata _parameters,
        bytes calldata _signature,
        address _receiver
    ) external {
        farmRewardDistributor.collectReferralRewards(
            msg.sender,
            _nonce,
            _lockupPeriod,
            _parameters,
            _signature,
            _receiver
        );
    }

    function collectCampaignReward(
        uint32 _nonce,
        uint16 _rewardType,
        uint200 _amount,
        bytes calldata _signature,
        address _receiver
    ) external {
        protocolFeeDistributor.collectCampaignReward(msg.sender, _nonce, _rewardType, _amount, _signature, _receiver);
    }

    function collectReferralCampaignRewards(
        uint32 _nonce,
        IProtocolFeeDistributor.CollectReferralTokenRewardParameter[] calldata _parameters,
        bytes calldata _signature,
        address _receiver
    ) external {
        protocolFeeDistributor.collectReferralCampaignRewards(msg.sender, _nonce, _parameters, _signature, _receiver);
    }
}
