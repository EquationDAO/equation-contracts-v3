// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../libraries/PriceUtil.sol";
import "./ConfigurableUpgradeable.sol";
import "../plugins/RouterUpgradeable.sol";
import "../libraries/LiquidityPositionUtil.sol";
import "../distributor/interfaces/IProtocolFeeDistributor.sol";

abstract contract MarketManagerStatesUpgradeable is IMarketManager, ConfigurableUpgradeable {
    /// @custom:storage-location erc7201:EquationDAO.storage.MarketManagerStatesUpgradeable
    struct MarketManagerStatesStorage {
        uint256 usdBalance;
        IProtocolFeeDistributor feeDistributor;
        RouterUpgradeable router;
        IPriceFeed priceFeed;
        mapping(IMarketDescriptor market => uint256 status) reentrancyStatus;
        mapping(IMarketDescriptor market => State) marketStates;
    }

    // keccak256(abi.encode(uint256(keccak256("EquationDAO.storage.MarketManagerStatesUpgradeable")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant MARKET_MANAGER_STATES_UPGRADEABLE_STORAGE =
        0x7a038b70cf8747a1ccdedee249b475e8876cf28ae42d16ac718303729a7db100;
    uint256 internal constant NOT_ENTERED = 1;
    uint256 internal constant ENTERED = 2;

    modifier nonReentrantForMarket(IMarketDescriptor _market) {
        if (!_isEnabledMarket(_market)) revert IConfigurable.MarketNotEnabled(_market);

        MarketManagerStatesStorage storage $ = _statesStorage();

        if ($.reentrancyStatus[_market] == ENTERED) revert ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall();

        $.reentrancyStatus[_market] = ENTERED;
        _;
        $.reentrancyStatus[_market] = NOT_ENTERED;
    }

    function __MarketManagerStates_init(
        IERC20 _usd,
        IProtocolFeeDistributor _feeDistributor,
        RouterUpgradeable _router,
        IPriceFeed _priceFeed
    ) internal onlyInitializing {
        __Configurable_init(_usd);
        __MarketManagerStates_init_unchained(_feeDistributor, _router, _priceFeed);
    }

    function __MarketManagerStates_init_unchained(
        IProtocolFeeDistributor _feeDistributor,
        RouterUpgradeable _router,
        IPriceFeed _priceFeed
    ) internal onlyInitializing {
        MarketManagerStatesStorage storage $ = _statesStorage();
        ($.feeDistributor, $.router, $.priceFeed) = (_feeDistributor, _router, _priceFeed);

        emit PriceFeedChanged(IPriceFeed(address(0)), _priceFeed);
    }

    function router() external view returns (RouterUpgradeable) {
        return _statesStorage().router;
    }

    /// @inheritdoc IMarketManager
    function priceStates(IMarketDescriptor _market) external view override returns (PriceState memory) {
        return _statesStorage().marketStates[_market].priceState;
    }

    function usdBalance() external view returns (uint256) {
        return _statesStorage().usdBalance;
    }

    /// @inheritdoc IMarketManager
    function usdBalances(IMarketDescriptor _market) external view override returns (uint256) {
        return _statesStorage().marketStates[_market].usdBalance;
    }

    /// @inheritdoc IMarketManager
    function protocolFees(IMarketDescriptor _market) external view override returns (uint128) {
        return _statesStorage().marketStates[_market].protocolFee;
    }

    function priceFeed() external view returns (IPriceFeed) {
        return _statesStorage().priceFeed;
    }

    /// @inheritdoc IMarketLiquidityPosition
    function globalLiquidityPositions(
        IMarketDescriptor _market
    ) external view override returns (GlobalLiquidityPosition memory) {
        return _statesStorage().marketStates[_market].globalLiquidityPosition;
    }

    /// @inheritdoc IMarketLiquidityPosition
    function liquidityPositions(
        IMarketDescriptor _market,
        address _account
    ) external view override returns (LiquidityPosition memory) {
        return _statesStorage().marketStates[_market].liquidityPositions[_account];
    }

    /// @inheritdoc IMarketPosition
    function globalPositions(
        IMarketDescriptor _market
    ) external view override returns (IMarketManager.GlobalPosition memory) {
        return _statesStorage().marketStates[_market].globalPosition;
    }

    /// @inheritdoc IMarketPosition
    function positions(
        IMarketDescriptor _market,
        address _account,
        Side _side
    ) external view override returns (IMarketManager.Position memory) {
        return _statesStorage().marketStates[_market].positions[_account][_side];
    }

    /// @inheritdoc IMarketManager
    function globalLiquidationFunds(
        IMarketDescriptor _market
    ) external view override returns (IMarketManager.GlobalLiquidationFund memory) {
        return _statesStorage().marketStates[_market].globalLiquidationFund;
    }

    /// @inheritdoc IMarketManager
    function liquidationFundPositions(
        IMarketDescriptor _market,
        address _account
    ) external view override returns (uint256) {
        return _statesStorage().marketStates[_market].liquidationFundPositions[_account];
    }

    /// @inheritdoc IMarketManager
    function marketPriceX96s(
        IMarketDescriptor _market,
        Side _side
    ) external view override returns (uint160 marketPriceX96) {
        MarketManagerStatesStorage storage $ = _statesStorage();
        State storage state = $.marketStates[_market];
        marketPriceX96 = PriceUtil.calculateMarketPriceX96(
            state.globalLiquidityPosition.side,
            _side,
            MarketUtil.chooseIndexPriceX96($.priceFeed, _market, _side),
            state.priceState.basisIndexPriceX96,
            state.priceState.premiumRateX96
        );
    }

    function _statesStorage() internal pure returns (MarketManagerStatesStorage storage $) {
        // prettier-ignore
        assembly { $.slot := MARKET_MANAGER_STATES_UPGRADEABLE_STORAGE }
    }
}
