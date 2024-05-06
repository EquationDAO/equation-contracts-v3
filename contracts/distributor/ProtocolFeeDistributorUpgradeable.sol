// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.23;

import "./interfaces/IProtocolFeeDistributor.sol";
import "./BaseDistributorUpgradeable.sol";
import "../libraries/Constants.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract ProtocolFeeDistributorUpgradeable is
    IProtocolFeeDistributor,
    BaseDistributorUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    IFeeDistributor public feeDistributor;
    IERC20 public usd;
    uint256 public campaignBalance;
    /// @inheritdoc IProtocolFeeDistributor
    uint32 public override campaignRate;

    /// @inheritdoc IProtocolFeeDistributor
    mapping(uint16 rewardType => string description) public override rewardTypeDescriptions;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IFeeDistributor _feeDistributor, IEFC _EFC, IERC20 _usd, address _signer) public initializer {
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        BaseDistributorUpgradeable.__BaseDistributor_init(_EFC, _signer);

        (feeDistributor, usd) = (_feeDistributor, _usd);

        setRewardType(1, "ProfitMargin");
        setRewardType(2, "ReferralProfitMargin");
    }

    /// @inheritdoc IProtocolFeeDistributor
    function setCampaignRate(uint32 _newRate) external override onlyGov {
        if (_newRate > Constants.BASIS_POINTS_DIVISOR) revert InvalidCampaignRate(_newRate);

        campaignRate = _newRate;
        emit CampaignRateChanged(_newRate);
    }

    /// @inheritdoc IProtocolFeeDistributor
    function setRewardType(uint16 _rewardType, string memory _description) public override onlyGov {
        require(bytes(_description).length <= 32);

        rewardTypeDescriptions[_rewardType] = _description;
        emit RewardTypeDescriptionSet(_rewardType, _description);
    }

    /// @inheritdoc IProtocolFeeDistributor
    function deposit() external override nonReentrant {
        uint256 balanceAfter = usd.balanceOf(address(this));
        uint256 amount = balanceAfter - campaignBalance;

        uint256 campaignAmount = (amount * campaignRate) / Constants.BASIS_POINTS_DIVISOR;

        unchecked {
            campaignBalance += campaignAmount;
            emit CampaignAmountChanged(msg.sender, campaignAmount);

            uint256 feeAmount = amount - campaignAmount;
            usd.safeTransfer(address(feeDistributor), feeAmount);
            feeDistributor.depositFee(feeAmount);
        }
    }

    /// @inheritdoc IProtocolFeeDistributor
    function collectCampaignReward(
        address _account,
        uint32 _nonce,
        uint16 _rewardType,
        uint200 _amount,
        bytes calldata _signature,
        address _receiver
    ) external override onlyCollector nonReentrant {
        if (_receiver == address(0)) _receiver = msg.sender;

        collectReward(_account, _nonce, _rewardType, _amount, _signature, _receiver, bytes(""));
    }

    /// @inheritdoc IProtocolFeeDistributor
    function collectReferralCampaignRewards(
        address _account,
        uint32 _nonce,
        CollectReferralTokenRewardParameter[] calldata _parameters,
        bytes calldata _signature,
        address _receiver
    ) external override onlyCollector nonReentrant {
        if (_receiver == address(0)) _receiver = msg.sender;

        collectReferalRewards(_account, _nonce, _parameters, _signature, _receiver, bytes(""));
    }

    /// @inheritdoc BaseDistributorUpgradeable
    function afterCollectRewardFinished(
        address _account,
        uint32 _nonce,
        uint16 _rewardType,
        uint200 _collectableReward,
        address _receiver,
        bytes memory /* _data */
    ) internal virtual override {
        transferCampaignReward(_receiver, _collectableReward);
        emit CampaignRewardCollected(_account, _nonce, 0, _rewardType, _collectableReward, _receiver);
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
        emit CampaignRewardCollected(_account, _nonce, _referralToken, _rewardType, _collectableReward, _receiver);
    }

    /// @inheritdoc BaseDistributorUpgradeable
    function afterCollectReferralRewardsFinished(
        address /* _account */,
        uint32 /* _nonce */,
        uint200 _totalCollectableReward,
        address _receiver,
        bytes memory /* _data */
    ) internal virtual override {
        transferCampaignReward(_receiver, _totalCollectableReward);
    }

    /// @inheritdoc BaseDistributorUpgradeable
    function afterCollectMarketRewardFinished(
        address /* _account */,
        uint32 /* _nonce */,
        uint16 /* _rewardType */,
        IMarketDescriptor /* _market */,
        uint200 /* _collectableReward */,
        address /* _receiver */,
        bytes memory /* _data */
    ) internal virtual override {}

    /// @inheritdoc BaseDistributorUpgradeable
    function checkRewardType(uint16 _rewardType) internal virtual override {
        if (bytes(rewardTypeDescriptions[_rewardType]).length == 0)
            revert IFarmRewardDistributorV2.InvalidRewardType(_rewardType);
    }

    function transferCampaignReward(address _to, uint256 _amount) internal {
        if (_amount > campaignBalance) revert InsufficientBalance(campaignBalance, _amount);
        // prettier-ignore
        unchecked { campaignBalance -= _amount; }

        usd.safeTransfer(_to, _amount);
    }
}
