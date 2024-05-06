// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.23;

import "../libraries/Constants.sol";
import "./interfaces/IFarmRewardDistributor.sol";
import "./BaseDistributorUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract FarmRewardDistributorUpgradeable is
    IFarmRewardDistributor,
    BaseDistributorUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    IERC20 public token;
    IFeeDistributor public feeDistributor;
    IFarmRewardDistributorV2 public distributorV2;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IERC20 _token,
        IFeeDistributor _feeDistributor,
        IFarmRewardDistributorV2 _distributorV2,
        IEFC _EFC
    ) public initializer {
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        BaseDistributorUpgradeable.__BaseDistributor_init(_EFC, _distributorV2.signer());

        (token, feeDistributor, distributorV2) = (_token, _feeDistributor, _distributorV2);

        _token.approve(address(_feeDistributor), type(uint256).max);
    }

    /// @inheritdoc IFarmRewardDistributor
    function collectReward(
        address _account,
        uint32 _nonce,
        uint16 _lockupPeriod,
        uint16 _rewardType,
        uint200 _amount,
        bytes calldata _signature,
        address _receiver
    ) external override onlyCollector nonReentrant {
        if (_receiver == address(0)) _receiver = msg.sender;

        uint32 lockupFreeRate = distributorV2.lockupFreeRates(_lockupPeriod);
        if (lockupFreeRate == 0) revert IFeeDistributor.InvalidLockupPeriod(_lockupPeriod);

        collectReward(
            _account,
            _nonce,
            _rewardType,
            _amount,
            _signature,
            _receiver,
            abi.encode(_lockupPeriod, lockupFreeRate)
        );
    }

    /// @inheritdoc IFarmRewardDistributor
    function collectReferralRewards(
        address _account,
        uint32 _nonce,
        uint16 _lockupPeriod,
        CollectReferralTokenRewardParameter[] calldata _parameters,
        bytes calldata _signature,
        address _receiver
    ) external override onlyCollector nonReentrant {
        if (_receiver == address(0)) _receiver = msg.sender;

        uint32 lockupFreeRate = distributorV2.lockupFreeRates(_lockupPeriod);
        if (lockupFreeRate == 0) revert IFeeDistributor.InvalidLockupPeriod(_lockupPeriod);

        collectReferalRewards(
            _account,
            _nonce,
            _parameters,
            _signature,
            _receiver,
            abi.encode(_lockupPeriod, lockupFreeRate)
        );
    }

    /// @inheritdoc IFarmRewardDistributor
    function collectMarketReward(
        address _account,
        uint32 _nonce,
        uint16 _lockupPeriod,
        uint16 _rewardType,
        IMarketDescriptor _market,
        uint200 _amount,
        bytes calldata _signature,
        address _receiver
    ) external override onlyCollector nonReentrant {
        if (_receiver == address(0)) _receiver = msg.sender;

        uint32 lockupFreeRate = distributorV2.lockupFreeRates(_lockupPeriod);
        if (lockupFreeRate == 0) revert IFeeDistributor.InvalidLockupPeriod(_lockupPeriod);

        collectMarketReward(
            _account,
            _nonce,
            _rewardType,
            _market,
            _amount,
            _signature,
            _receiver,
            abi.encode(_lockupPeriod, lockupFreeRate)
        );
    }

    /// @inheritdoc BaseDistributorUpgradeable
    function afterCollectRewardFinished(
        address _account,
        uint32 _nonce,
        uint16 _rewardType,
        uint200 _collectableReward,
        address _receiver,
        bytes memory _data
    ) internal virtual override {
        (uint16 lockupPeriod, uint32 lockupFreeRate) = abi.decode(_data, (uint16, uint32));
        lockupAndBurnToken(_account, lockupPeriod, lockupFreeRate, _collectableReward, _receiver);

        emit IFarmRewardDistributorV2.RewardCollected(
            address(0),
            _account,
            _rewardType,
            0,
            _nonce,
            _receiver,
            _collectableReward
        );
    }

    /// @inheritdoc BaseDistributorUpgradeable
    function afterReferralRewardSettled(
        address _account,
        uint32 _nonce,
        uint16 _referralToken,
        uint16 _rewardType,
        uint200 _collectableReward,
        address _receiver,
        bytes memory /* _data */
    ) internal virtual override {
        emit IFarmRewardDistributorV2.RewardCollected(
            address(0),
            _account,
            _rewardType,
            _referralToken,
            _nonce,
            _receiver,
            _collectableReward
        );
    }

    /// @inheritdoc BaseDistributorUpgradeable
    function afterCollectReferralRewardsFinished(
        address _account,
        uint32 /* _nonce */,
        uint200 _totalCollectableReward,
        address _receiver,
        bytes memory _data
    ) internal virtual override {
        (uint16 lockupPeriod, uint32 lockupFreeRate) = abi.decode(_data, (uint16, uint32));
        lockupAndBurnToken(_account, lockupPeriod, lockupFreeRate, _totalCollectableReward, _receiver);
    }

    /// @inheritdoc BaseDistributorUpgradeable
    function afterCollectMarketRewardFinished(
        address _account,
        uint32 _nonce,
        uint16 _rewardType,
        IMarketDescriptor _market,
        uint200 _collectableReward,
        address _receiver,
        bytes memory _data
    ) internal virtual override {
        (uint16 lockupPeriod, uint32 lockupFreeRate) = abi.decode(_data, (uint16, uint32));
        lockupAndBurnToken(_account, lockupPeriod, lockupFreeRate, _collectableReward, _receiver);

        emit IFarmRewardDistributorV2.RewardCollected(
            address(_market),
            _account,
            _rewardType,
            0,
            _nonce,
            _receiver,
            _collectableReward
        );
    }

    /// @inheritdoc BaseDistributorUpgradeable
    function checkRewardType(uint16 _rewardType) internal virtual override {
        if (bytes(distributorV2.rewardTypesDescriptions(_rewardType)).length == 0)
            revert IFarmRewardDistributorV2.InvalidRewardType(_rewardType);
    }

    function lockupAndBurnToken(
        address _account,
        uint16 _lockupPeriod,
        uint32 _lockupFreeRate,
        uint200 _totalCollectableReward,
        address _receiver
    ) internal virtual {
        Address.functionCall(
            address(token),
            abi.encodeWithSignature("mint(address,uint256)", address(this), _totalCollectableReward)
        );

        unchecked {
            uint256 lockedOrUnlockedAmount = (uint256(_totalCollectableReward) * _lockupFreeRate) /
                Constants.BASIS_POINTS_DIVISOR;
            uint256 burnedAmount = _totalCollectableReward - lockedOrUnlockedAmount;

            // first burn the token
            if (burnedAmount > 0) token.safeTransfer(address(0x1), burnedAmount);

            // then lockup or transfer the token
            if (_lockupPeriod == 0) token.safeTransfer(_receiver, lockedOrUnlockedAmount);
            else feeDistributor.stake(lockedOrUnlockedAmount, _receiver, _lockupPeriod);

            emit IFarmRewardDistributorV2.RewardLockedAndBurned(
                _account,
                _lockupPeriod,
                _receiver,
                lockedOrUnlockedAmount,
                burnedAmount
            );
        }
    }
}
