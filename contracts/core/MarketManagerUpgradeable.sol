// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.23;

import "../libraries/PositionUtil.sol";
import "./MarketManagerStatesUpgradeable.sol";

/// @custom:oz-upgrades-unsafe-allow external-library-linking
contract MarketManagerUpgradeable is MarketManagerStatesUpgradeable {
    using SafeCast for *;
    using SafeERC20 for IERC20;
    using MarketUtil for State;
    using PositionUtil for State;
    using FundingRateUtil for State;
    using LiquidityPositionUtil for State;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IERC20 _usd,
        IProtocolFeeDistributor _feeDistributor,
        RouterUpgradeable _router,
        IPriceFeed _priceFeed
    ) public initializer {
        __MarketManagerStates_init(_usd, _feeDistributor, _router, _priceFeed);
    }

    /// @inheritdoc IMarketLiquidityPosition
    function increaseLiquidityPosition(
        IMarketDescriptor _market,
        address _account,
        uint128 _marginDelta,
        uint128 _liquidityDelta
    ) external override nonReentrantForMarket(_market) returns (uint128 marginAfter) {
        _onlyRouter();

        MarketManagerStatesStorage storage $ = _statesStorage();
        State storage state = $.marketStates[_market];
        IConfigurable.MarketConfig storage marketCfg = _configurableStorage().marketConfigs[_market];
        IPriceFeed priceFeed = $.priceFeed;
        state.settleFundingFee(marketCfg, priceFeed, _market);

        if (_marginDelta > 0) _validateTransferInAndUpdateBalance(state, _marginDelta);

        marginAfter = state.increaseLiquidityPosition(
            marketCfg,
            LiquidityPositionUtil.IncreaseLiquidityPositionParameter({
                market: _market,
                account: _account,
                marginDelta: _marginDelta,
                liquidityDelta: _liquidityDelta,
                priceFeed: priceFeed
            })
        );

        if (_liquidityDelta > 0) {
            state.changePriceVertices(marketCfg.priceConfig, _market, priceFeed.getMaxPriceX96(_market));
            state.changeMaxSize(marketCfg.baseConfig, _market, priceFeed.getMaxPriceX96(_market));
        }
    }

    /// @inheritdoc IMarketLiquidityPosition
    function decreaseLiquidityPosition(
        IMarketDescriptor _market,
        address _account,
        uint128 _marginDelta,
        uint128 _liquidityDelta,
        address _receiver
    ) external override nonReentrantForMarket(_market) returns (uint128 marginAfter) {
        _onlyRouter();

        MarketManagerStatesStorage storage $ = _statesStorage();
        State storage state = $.marketStates[_market];
        IConfigurable.MarketConfig storage marketCfg = _configurableStorage().marketConfigs[_market];
        IPriceFeed priceFeed = $.priceFeed;
        state.settleFundingFee(marketCfg, priceFeed, _market);

        (marginAfter, _marginDelta) = state.decreaseLiquidityPosition(
            marketCfg,
            LiquidityPositionUtil.DecreaseLiquidityPositionParameter({
                market: _market,
                account: _account,
                marginDelta: _marginDelta,
                liquidityDelta: _liquidityDelta,
                priceFeed: priceFeed,
                receiver: _receiver
            })
        );

        if (_marginDelta > 0) _transferOutAndUpdateBalance(state, _receiver, _marginDelta);

        if (_liquidityDelta > 0) {
            state.changePriceVertices(marketCfg.priceConfig, _market, priceFeed.getMaxPriceX96(_market));
            state.changeMaxSize(marketCfg.baseConfig, _market, priceFeed.getMaxPriceX96(_market));
        }
    }

    /// @inheritdoc IMarketLiquidityPosition
    function liquidateLiquidityPosition(
        IMarketDescriptor _market,
        address _account,
        address _feeReceiver
    ) external override nonReentrantForMarket(_market) {
        _onlyRouter();

        MarketManagerStatesStorage storage $ = _statesStorage();
        State storage state = $.marketStates[_market];
        IConfigurable.MarketConfig storage marketCfg = _configurableStorage().marketConfigs[_market];
        IPriceFeed priceFeed = $.priceFeed;
        state.settleFundingFee(marketCfg, priceFeed, _market);

        uint64 liquidateExecutionFee = state.liquidateLiquidityPosition(
            marketCfg,
            LiquidityPositionUtil.LiquidateLiquidityPositionParameter({
                market: _market,
                account: _account,
                priceFeed: priceFeed,
                feeReceiver: _feeReceiver
            })
        );

        _transferOutAndUpdateBalance(state, _feeReceiver, liquidateExecutionFee);

        state.changePriceVertices(marketCfg.priceConfig, _market, priceFeed.getMaxPriceX96(_market));
        state.changeMaxSize(marketCfg.baseConfig, _market, priceFeed.getMaxPriceX96(_market));
    }

    /// @inheritdoc IMarketManager
    function govUseLiquidationFund(
        IMarketDescriptor _market,
        address _receiver,
        uint128 _liquidationFundDelta
    ) external override nonReentrantForMarket(_market) {
        _onlyGov();

        State storage state = _statesStorage().marketStates[_market];
        state.govUseLiquidationFund(_market, _liquidationFundDelta, _receiver);

        _transferOutAndUpdateBalance(state, _receiver, _liquidationFundDelta);
    }

    /// @inheritdoc IMarketManager
    function increaseLiquidationFundPosition(
        IMarketDescriptor _market,
        address _account,
        uint128 _liquidityDelta
    ) external override nonReentrantForMarket(_market) {
        _onlyRouter();

        State storage state = _statesStorage().marketStates[_market];
        _validateTransferInAndUpdateBalance(state, _liquidityDelta);

        state.increaseLiquidationFundPosition(_market, _account, _liquidityDelta);
    }

    /// @inheritdoc IMarketManager
    function decreaseLiquidationFundPosition(
        IMarketDescriptor _market,
        address _account,
        uint128 _liquidityDelta,
        address _receiver
    ) external override nonReentrantForMarket(_market) {
        _onlyRouter();

        State storage state = _statesStorage().marketStates[_market];
        state.decreaseLiquidationFundPosition(_market, _account, _liquidityDelta, _receiver);

        _transferOutAndUpdateBalance(state, _receiver, _liquidityDelta);
    }

    /// @inheritdoc IMarketPosition
    function increasePosition(
        IMarketDescriptor _market,
        address _account,
        Side _side,
        uint128 _marginDelta,
        uint128 _sizeDelta
    ) external override nonReentrantForMarket(_market) returns (uint160 tradePriceX96) {
        _onlyRouter();

        MarketManagerStatesStorage storage $ = _statesStorage();
        State storage state = $.marketStates[_market];
        IConfigurable.MarketConfig storage marketCfg = _configurableStorage().marketConfigs[_market];
        IPriceFeed priceFeed = $.priceFeed;
        state.settleFundingFee(marketCfg, priceFeed, _market);

        if (_marginDelta > 0) _validateTransferInAndUpdateBalance(state, _marginDelta);

        return
            state.increasePosition(
                marketCfg,
                PositionUtil.IncreasePositionParameter({
                    market: _market,
                    account: _account,
                    side: _side,
                    marginDelta: _marginDelta,
                    sizeDelta: _sizeDelta,
                    priceFeed: priceFeed
                })
            );
    }

    /// @inheritdoc IMarketPosition
    function decreasePosition(
        IMarketDescriptor _market,
        address _account,
        Side _side,
        uint128 _marginDelta,
        uint128 _sizeDelta,
        address _receiver
    ) external override returns (uint160 tradePriceX96) {
        (tradePriceX96, ) = decreasePositionV2(_market, _account, _side, _marginDelta, _sizeDelta, _receiver);
    }

    /// @inheritdoc IMarketPosition
    function decreasePositionV2(
        IMarketDescriptor _market,
        address _account,
        Side _side,
        uint128 _marginDelta,
        uint128 _sizeDelta,
        address _receiver
    ) public override nonReentrantForMarket(_market) returns (uint160 tradePriceX96, bool useEntryPriceAsTradePrice) {
        _onlyRouter();

        MarketManagerStatesStorage storage $ = _statesStorage();
        State storage state = $.marketStates[_market];
        ConfigurableUpgradeable.ConfigurableStorage storage configStorage = _configurableStorage();
        IConfigurable.MarketConfig storage marketCfg = configStorage.marketConfigs[_market];
        IPriceFeed priceFeed = $.priceFeed;
        state.settleFundingFee(marketCfg, priceFeed, _market);

        (tradePriceX96, useEntryPriceAsTradePrice, _marginDelta) = state.decreasePosition(
            marketCfg,
            PositionUtil.DecreasePositionParameter({
                market: _market,
                account: _account,
                side: _side,
                marginDelta: _marginDelta,
                sizeDelta: _sizeDelta,
                priceFeed: priceFeed,
                receiver: _receiver,
                minProfitDuration: configStorage.marketMinProfitDurations[_market]
            })
        );
        if (_marginDelta > 0) _transferOutAndUpdateBalance(state, _receiver, _marginDelta);
    }

    /// @inheritdoc IMarketPosition
    function liquidatePosition(
        IMarketDescriptor _market,
        address _account,
        Side _side,
        address _feeReceiver
    ) external override nonReentrantForMarket(_market) {
        _onlyRouter();

        MarketManagerStatesStorage storage $ = _statesStorage();
        State storage state = $.marketStates[_market];
        IConfigurable.MarketConfig storage marketCfg = _configurableStorage().marketConfigs[_market];
        IPriceFeed priceFeed = $.priceFeed;
        state.settleFundingFee(marketCfg, priceFeed, _market);

        state.liquidatePosition(
            marketCfg,
            PositionUtil.LiquidatePositionParameter({
                market: _market,
                account: _account,
                side: _side,
                priceFeed: priceFeed,
                feeReceiver: _feeReceiver
            })
        );

        // transfer liquidation fee directly to fee receiver
        _transferOutAndUpdateBalance(state, _feeReceiver, marketCfg.baseConfig.liquidationExecutionFee);
    }

    /// @inheritdoc IMarketManager
    function setPriceFeed(IPriceFeed _priceFeed) external override nonReentrant {
        _onlyGov();
        MarketManagerStatesStorage storage $ = _statesStorage();
        IPriceFeed priceFeedBefore = $.priceFeed;
        $.priceFeed = _priceFeed;
        emit PriceFeedChanged(priceFeedBefore, _priceFeed);
    }

    /// @inheritdoc IMarketManager
    /// @dev This function does not include the nonReentrantForMarket modifier because it is intended
    /// to be called internally by the contract itself.
    function changePriceVertex(
        IMarketDescriptor _market,
        uint8 _startExclusive,
        uint8 _endInclusive
    ) external override {
        if (msg.sender != address(this)) revert InvalidCaller(address(this));

        MarketManagerStatesStorage storage $ = _statesStorage();
        State storage state = $.marketStates[_market];
        unchecked {
            // If the vertex represented by end is the same as the vertex represented by end + 1,
            // then the vertices in the range (start, LATEST_VERTEX] need to be updated
            PriceState storage priceState = state.priceState;
            if (_endInclusive < Constants.LATEST_VERTEX) {
                PriceVertex memory previous = priceState.priceVertices[_endInclusive];
                PriceVertex memory next = priceState.priceVertices[_endInclusive + 1];
                if (previous.size >= next.size || previous.premiumRateX96 >= next.premiumRateX96)
                    _endInclusive = Constants.LATEST_VERTEX;
            }
        }
        state.changePriceVertex(
            _configurableStorage().marketConfigs[_market].priceConfig,
            _market,
            $.priceFeed.getMaxPriceX96(_market),
            _startExclusive,
            _endInclusive
        );
    }

    /// @inheritdoc IMarketManager
    function settleFundingFee(IMarketDescriptor _market) external override nonReentrantForMarket(_market) {
        _onlyRouter();

        MarketManagerStatesStorage storage $ = _statesStorage();
        State storage state = $.marketStates[_market];
        IConfigurable.MarketConfig storage marketCfg = _configurableStorage().marketConfigs[_market];
        state.settleFundingFee(marketCfg, $.priceFeed, _market);
    }

    /// @inheritdoc IMarketManager
    function collectProtocolFee(IMarketDescriptor _market) external override nonReentrantForMarket(_market) {
        MarketManagerStatesStorage storage $ = _statesStorage();
        State storage state = $.marketStates[_market];

        IProtocolFeeDistributor feeDistributor = $.feeDistributor;
        uint128 protocolFee = state.protocolFee;
        state.protocolFee = 0;
        _transferOutAndUpdateBalance(state, address(feeDistributor), protocolFee);
        feeDistributor.deposit();
        emit ProtocolFeeCollected(_market, protocolFee);
    }

    /// @inheritdoc ConfigurableUpgradeable
    function afterMarketEnabled(IMarketDescriptor _market) internal override {
        MarketManagerStatesStorage storage $ = _statesStorage();
        assert($.reentrancyStatus[_market] == 0);
        $.reentrancyStatus[_market] = NOT_ENTERED;
        $.marketStates[_market].globalPosition.lastFundingFeeSettleTime = block.timestamp.toUint64();
    }

    /// @inheritdoc ConfigurableUpgradeable
    function afterMarketBaseConfigChanged(IMarketDescriptor _market) internal override {
        MarketManagerStatesStorage storage $ = _statesStorage();
        $.marketStates[_market].changeMaxSize(
            _configurableStorage().marketConfigs[_market].baseConfig,
            _market,
            $.priceFeed.getMaxPriceX96(_market)
        );
    }

    /// @inheritdoc ConfigurableUpgradeable
    function afterMarketPriceConfigChanged(IMarketDescriptor _market) internal override {
        MarketManagerStatesStorage storage $ = _statesStorage();
        $.marketStates[_market].changePriceVertices(
            _configurableStorage().marketConfigs[_market].priceConfig,
            _market,
            $.priceFeed.getMaxPriceX96(_market)
        );
    }

    function _onlyRouter() private view {
        if (msg.sender != address(_statesStorage().router)) revert InvalidCaller(address(_statesStorage().router));
    }

    function _validateTransferInAndUpdateBalance(State storage _state, uint128 _amount) private {
        uint256 balanceAfter = USD().balanceOf(address(this));
        MarketManagerStatesStorage storage $ = _statesStorage();
        if (balanceAfter - $.usdBalance < _amount) revert InsufficientBalance($.usdBalance, _amount);
        $.usdBalance += _amount;
        _state.usdBalance += _amount;
    }

    function _transferOutAndUpdateBalance(State storage _state, address _to, uint128 _amount) private {
        MarketManagerStatesStorage storage $ = _statesStorage();
        $.usdBalance -= _amount;
        _state.usdBalance -= _amount;
        USD().safeTransfer(_to, _amount);
    }
}
