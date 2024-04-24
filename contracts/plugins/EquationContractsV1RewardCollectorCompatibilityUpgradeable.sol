// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../IEquationContractsV1Minimum.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @notice The contract implementation is used to be compatible with the farming rewards, referral fees,
/// staking rewards and architect rewards of Equation Contracts V1
/// @dev In order for this contract to work properly, it needs to be registered as a plugin of
/// Equation Contracts V1's Router, and it needs to be registered as a collector of Equation
/// Contracts V1's IFarmRewardDistributorV2
abstract contract EquationContractsV1RewardCollectorCompatibilityUpgradeable is Initializable {
    /// @custom:storage-location erc7201:EquationDAO.storage.EquationContractsV1RewardCollectorCompatibilityUpgradeable
    struct CompatibilityStorage {
        IRouter routerV1;
        IFarmRewardDistributorV2 distributorV2;
        IEFC EFC;
    }

    // keccak256(abi.encode(uint256(keccak256("EquationDAO.storage.EquationContractsV1RewardCollectorCompatibilityUpgradeable")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant COMPATIBILITY_UPGRADEABLE_STORAGE =
        0x67cb4906bdc480e575a057f418b4be01342e72bb0c1bb94aa1df75f5ad192600;

    error InvalidCaller(address caller, address requiredCaller);

    function __EquationContractsV1RewardCollectorCompatibilityUpgradeable_init(
        IRouter _routerV1,
        IFarmRewardDistributorV2 _distributorV2
    ) internal initializer {
        __EquationContractsV1RewardCollectorCompatibilityUpgradeable_init_unchained(_routerV1, _distributorV2);
    }

    function __EquationContractsV1RewardCollectorCompatibilityUpgradeable_init_unchained(
        IRouter _routerV1,
        IFarmRewardDistributorV2 _distributorV2
    ) internal onlyInitializing {
        CompatibilityStorage storage $ = _compatibilityStorage();
        ($.routerV1, $.distributorV2, $.EFC) = (_routerV1, _distributorV2, _distributorV2.EFC());
    }

    function collectContractsV1ReferralFeeBatch(
        IPool[] calldata _pools,
        uint256[] calldata _referralTokens
    ) external virtual returns (uint256 amount) {
        _validateOwner(_referralTokens);

        IRouter routerV1 = _compatibilityStorage().routerV1;

        IPool pool;
        uint256 poolsLen = _pools.length;
        uint256 tokensLen;
        for (uint256 i; i < poolsLen; ++i) {
            (pool, tokensLen) = (_pools[i], _referralTokens.length);
            for (uint256 j; j < tokensLen; ++j)
                amount += routerV1.pluginCollectReferralFee(pool, _referralTokens[j], address(this));
        }
    }

    function collectContractsV1FarmLiquidityRewardBatch(
        IPool[] calldata _pools
    ) external virtual returns (uint256 rewardDebt) {
        rewardDebt = _compatibilityStorage().routerV1.pluginCollectFarmLiquidityRewardBatch(
            _pools,
            msg.sender,
            address(this)
        );
    }

    function collectContractsV1FarmRiskBufferFundRewardBatch(
        IPool[] calldata _pools
    ) external virtual returns (uint256 rewardDebt) {
        rewardDebt = _compatibilityStorage().routerV1.pluginCollectFarmRiskBufferFundRewardBatch(
            _pools,
            msg.sender,
            address(this)
        );
    }

    function collectContractsV1FarmReferralRewardBatch(
        IPool[] calldata _pools,
        uint256[] calldata _referralTokens
    ) external virtual returns (uint256 rewardDebt) {
        _validateOwner(_referralTokens);
        return
            _compatibilityStorage().routerV1.pluginCollectFarmReferralRewardBatch(
                _pools,
                _referralTokens,
                address(this)
            );
    }

    function collectContractsV1StakingRewardBatch(
        uint256[] calldata _ids
    ) external virtual returns (uint256 rewardDebt) {
        rewardDebt = _compatibilityStorage().routerV1.pluginCollectStakingRewardBatch(msg.sender, address(this), _ids);
    }

    function collectContractsV1V3PosStakingRewardBatch(
        uint256[] calldata _ids
    ) external virtual returns (uint256 rewardDebt) {
        rewardDebt = _compatibilityStorage().routerV1.pluginCollectV3PosStakingRewardBatch(
            msg.sender,
            address(this),
            _ids
        );
    }

    function collectContractsV1ArchitectRewardBatch(
        uint256[] calldata _tokenIDs
    ) external virtual returns (uint256 rewardDebt) {
        _validateOwner(_tokenIDs);
        rewardDebt = _compatibilityStorage().routerV1.pluginCollectArchitectRewardBatch(address(this), _tokenIDs);
    }

    function collectContractsV1FarmRewardBatch(
        PackedValue _nonceAndLockupPeriod,
        PackedValue[] calldata _packedPoolRewardValues,
        bytes calldata _signature,
        address _receiver
    ) external virtual {
        _compatibilityStorage().distributorV2.collectBatch(
            msg.sender,
            _nonceAndLockupPeriod,
            _packedPoolRewardValues,
            _signature,
            _receiver
        );
    }

    function _validateOwner(uint256[] calldata _referralTokens) internal view virtual {
        (address caller, uint256 tokensLen) = (msg.sender, _referralTokens.length);
        IEFC efc = _compatibilityStorage().EFC;
        for (uint256 i; i < tokensLen; ++i) {
            if (efc.ownerOf(_referralTokens[i]) != caller)
                revert InvalidCaller(caller, efc.ownerOf(_referralTokens[i]));
        }
    }

    function _compatibilityStorage() internal pure returns (CompatibilityStorage storage $) {
        // prettier-ignore
        assembly { $.slot := COMPATIBILITY_UPGRADEABLE_STORAGE }
    }
}
