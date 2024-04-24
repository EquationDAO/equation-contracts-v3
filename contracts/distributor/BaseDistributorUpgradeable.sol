// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./interfaces/IBaseDistributor.sol";
import "../governance/GovernableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

abstract contract BaseDistributorUpgradeable is IBaseDistributor, GovernableUpgradeable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /// @custom:storage-location erc7201:EquationDAO.storage.BaseDistributorUpgradeable
    struct BaseDistributorStorage {
        IEFC EFC;
        address signer;
        mapping(address collector => bool active) collectors;
        mapping(address account => uint32 nonce) nonces;
        mapping(address account => mapping(uint16 rewardType => uint200 amount)) collectedRewards;
        mapping(uint16 referralToken => mapping(uint16 rewardType => uint200 amount)) collectedReferralRewards;
    }

    // keccak256(abi.encode(uint256(keccak256("EquationDAO.storage.BaseDistributorUpgradeable")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant BASE_DISTRIBUTOR_UPGRADEABLE_STORAGE =
        0x628656e0a1ffda502b385910bf55190c5dd48cf0b164b1b3b20a69c85ef48600;

    modifier onlyCollector() {
        if (!_baseDistributorStorage().collectors[msg.sender]) revert Forbidden();
        _;
    }

    function __BaseDistributor_init(IEFC _EFC, address _signer) internal onlyInitializing {
        GovernableUpgradeable.__Governable_init();
        __BaseDistributor_init_unchained(_EFC, _signer);
    }

    function __BaseDistributor_init_unchained(IEFC _EFC, address _signer) internal onlyInitializing {
        BaseDistributorStorage storage $ = _baseDistributorStorage();
        ($.EFC, $.signer) = (_EFC, _signer);
    }

    /// @inheritdoc IBaseDistributor
    function setCollector(address _collector, bool _enabled) external override onlyGov {
        _baseDistributorStorage().collectors[_collector] = _enabled;
        emit IFarmRewardDistributorV2.CollectorUpdated(_collector, _enabled);
    }

    /// @inheritdoc IBaseDistributor
    function EFC() public view override returns (IEFC) {
        return _baseDistributorStorage().EFC;
    }

    /// @inheritdoc IBaseDistributor
    function signer() public view override returns (address) {
        return _baseDistributorStorage().signer;
    }

    /// @inheritdoc IBaseDistributor
    function collectors(address _collector) public view override returns (bool) {
        return _baseDistributorStorage().collectors[_collector];
    }

    /// @inheritdoc IBaseDistributor
    function nonces(address _account) public view override returns (uint32) {
        return _baseDistributorStorage().nonces[_account];
    }

    /// @inheritdoc IBaseDistributor
    function collectedRewards(address _account, uint16 _rewardType) public view override returns (uint200) {
        return _baseDistributorStorage().collectedRewards[_account][_rewardType];
    }

    /// @inheritdoc IBaseDistributor
    function collectedReferralRewards(
        uint16 _referralToken,
        uint16 _rewardType
    ) public view override returns (uint200) {
        return _baseDistributorStorage().collectedReferralRewards[_referralToken][_rewardType];
    }

    function collectReward(
        address _account,
        uint32 _nonce,
        uint16 _rewardType,
        uint200 _amount,
        bytes calldata _signature,
        address _receiver,
        bytes memory _data
    ) internal virtual returns (uint200 collectableReward) {
        BaseDistributorStorage storage $ = _baseDistributorStorage();
        checkNonce($, _account, _nonce);
        checkSignature($, _signature, abi.encode(_account, _nonce, _rewardType, _amount));
        checkRewardType(_rewardType);

        $.nonces[_account] = _nonce;

        mapping(uint16 => uint200) storage rewardTypeRewards = $.collectedRewards[_account];
        collectableReward = _amount - rewardTypeRewards[_rewardType];
        rewardTypeRewards[_rewardType] = _amount;

        afterCollectRewardFinished(_account, _nonce, _rewardType, collectableReward, _receiver, _data);
    }

    function collectReferalRewards(
        address _account,
        uint32 _nonce,
        CollectReferralTokenRewardParameter[] memory _parameters,
        bytes calldata _signature,
        address _receiver,
        bytes memory _data
    ) internal virtual returns (uint200 totalCollectableReward) {
        BaseDistributorStorage storage $ = _baseDistributorStorage();
        checkNonce($, _account, _nonce);
        checkSignature($, _signature, abi.encode(_account, _nonce, _parameters));

        $.nonces[_account] = _nonce;

        IEFC efc = $.EFC;
        CollectReferralTokenRewardParameter memory parameter;
        uint256 length = _parameters.length;
        for (uint256 i; i < length; ++i) {
            parameter = _parameters[i];
            checkRewardType(parameter.rewardType);

            if (efc.ownerOf(parameter.referralToken) != _account)
                revert IFeeDistributor.InvalidNFTOwner(_account, parameter.referralToken);

            mapping(uint16 => uint200) storage rewardTypeRewards = $.collectedReferralRewards[parameter.referralToken];
            uint200 collectableReward = parameter.amount - rewardTypeRewards[parameter.rewardType];
            totalCollectableReward += collectableReward;
            rewardTypeRewards[parameter.rewardType] = parameter.amount;

            afterReferralRewardSettled(
                _account,
                _nonce,
                parameter.referralToken,
                parameter.rewardType,
                collectableReward,
                _receiver,
                _data
            );
        }

        afterCollectReferralRewardsFinished(_account, _nonce, totalCollectableReward, _receiver, _data);
    }

    /// @dev Hook that is called after the reward is collected
    function afterCollectRewardFinished(
        address _account,
        uint32 _nonce,
        uint16 _rewardType,
        uint200 _collectableReward,
        address _receiver,
        bytes memory _data
    ) internal virtual;

    /// @dev Hook that is called after the referral reward is settled
    function afterReferralRewardSettled(
        address _account,
        uint32 _nonce,
        uint16 _referralToken,
        uint16 _rewardType,
        uint200 _collectableReward,
        address _receiver,
        bytes memory _data
    ) internal virtual;

    /// @dev Hook that is called after the referral reward is collected
    function afterCollectReferralRewardsFinished(
        address _account,
        uint32 _nonce,
        uint200 _totalCollectableReward,
        address _receiver,
        bytes memory _data
    ) internal virtual;

    function checkNonce(BaseDistributorStorage storage $, address _account, uint32 _nonce) internal view virtual {
        if (_nonce != $.nonces[_account] + 1) revert IFarmRewardDistributorV2.InvalidNonce(_nonce);
    }

    function checkSignature(
        BaseDistributorStorage storage $,
        bytes calldata _signature,
        bytes memory _message
    ) internal view virtual {
        address _signer = keccak256(_message).toEthSignedMessageHash().recover(_signature);
        if (_signer != $.signer) revert IFarmRewardDistributorV2.InvalidSignature();
    }

    /// @dev Check the reward type
    function checkRewardType(uint16 _rewardType) internal virtual;

    function _baseDistributorStorage() internal pure returns (BaseDistributorStorage storage $) {
        // prettier-ignore
        assembly { $.slot := BASE_DISTRIBUTOR_UPGRADEABLE_STORAGE }
    }
}
