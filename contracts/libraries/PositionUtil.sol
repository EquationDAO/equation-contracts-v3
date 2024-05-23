// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./PriceUtil.sol";
import "./FundingRateUtil.sol";

/// @notice Utility library for trader positions
library PositionUtil {
    using SafeCast for *;

    struct IncreasePositionParameter {
        IMarketDescriptor market;
        address account;
        Side side;
        uint128 marginDelta;
        uint128 sizeDelta;
        IPriceFeed priceFeed;
    }

    struct DecreasePositionParameter {
        IMarketDescriptor market;
        address account;
        Side side;
        uint128 marginDelta;
        uint128 sizeDelta;
        IPriceFeed priceFeed;
        address receiver;
        uint16 minProfitDuration;
    }

    struct LiquidatePositionParameter {
        IMarketDescriptor market;
        address account;
        Side side;
        IPriceFeed priceFeed;
        address feeReceiver;
    }

    struct MaintainMarginRateParameter {
        int256 margin;
        Side side;
        uint128 size;
        uint160 entryPriceX96;
        uint160 decreasePriceX96;
        bool liquidatablePosition;
    }

    struct LiquidateParameter {
        IMarketDescriptor market;
        address account;
        Side side;
        uint160 tradePriceX96;
        uint160 decreaseIndexPriceX96;
        int256 requiredFundingFee;
        address feeReceiver;
    }

    /// @notice Change the maximum available size after the liquidity changes
    /// @param _state The state of the market
    /// @param _baseCfg The base configuration of the market
    /// @param _market The descriptor used to describe the metadata of the market, such as symbol, name, decimals
    /// @param _indexPriceX96 The index price of the market, as a Q64.96
    function changeMaxSize(
        IMarketManager.State storage _state,
        IConfigurable.MarketBaseConfig storage _baseCfg,
        IMarketDescriptor _market,
        uint160 _indexPriceX96
    ) public {
        unchecked {
            uint128 maxSizeAfter = Math
                .mulDiv(
                    Math.min(_state.globalLiquidityPosition.liquidity, _baseCfg.maxPositionLiquidity),
                    uint256(_baseCfg.maxPositionValueRate) << 96,
                    uint256(Constants.BASIS_POINTS_DIVISOR) * _indexPriceX96
                )
                .toUint128();
            uint128 maxSizePerPositionAfter = uint128(
                (uint256(maxSizeAfter) * _baseCfg.maxSizeRatePerPosition) / Constants.BASIS_POINTS_DIVISOR
            );

            IMarketManager.GlobalPosition storage position = _state.globalPosition;
            position.maxSize = maxSizeAfter;
            position.maxSizePerPosition = maxSizePerPositionAfter;

            emit IMarketPosition.GlobalPositionSizeChanged(_market, maxSizeAfter, maxSizePerPositionAfter);
        }
    }

    function increasePosition(
        IMarketManager.State storage _state,
        IConfigurable.MarketConfig storage _marketCfg,
        IncreasePositionParameter memory _parameter
    ) public returns (uint160 tradePriceX96) {
        _parameter.side.requireValid();

        IConfigurable.MarketBaseConfig storage baseCfg = _marketCfg.baseConfig;
        IMarketManager.Position memory positionCache = _state.positions[_parameter.account][_parameter.side];
        if (positionCache.size == 0) {
            if (_parameter.sizeDelta == 0) revert IMarketErrors.PositionNotFound(_parameter.account, _parameter.side);

            MarketUtil.validateMargin(_parameter.marginDelta, baseCfg.minMarginPerPosition);
        }

        _validateGlobalLiquidity(_state.globalLiquidityPosition.liquidity);

        uint128 sizeAfter = positionCache.size;
        if (_parameter.sizeDelta > 0) {
            sizeAfter = _validateIncreaseSize(_state.globalPosition, positionCache.size, _parameter.sizeDelta);

            uint160 indexPriceX96 = MarketUtil.chooseIndexPriceX96(
                _parameter.priceFeed,
                _parameter.market,
                _parameter.side
            );

            uint136 netSizeSnapshot = MarketUtil.globalLiquidityPositionNetSize(_state.globalLiquidityPosition);

            IConfigurable.MarketPriceConfig storage priceConfig = _marketCfg.priceConfig;
            tradePriceX96 = PriceUtil.updatePriceState(
                _state.globalLiquidityPosition,
                _state.priceState,
                PriceUtil.UpdatePriceStateParameter({
                    market: _parameter.market,
                    side: _parameter.side,
                    sizeDelta: _parameter.sizeDelta,
                    indexPriceX96: indexPriceX96,
                    liquidationVertexIndex: priceConfig.liquidationVertexIndex,
                    liquidation: false,
                    dynamicDepthMode: priceConfig.dynamicDepthMode,
                    dynamicDepthLevel: priceConfig.dynamicDepthLevel
                })
            );

            _initializeAndSettleLiquidityUnrealizedPnL(
                _state.globalLiquidityPosition,
                _parameter.market,
                netSizeSnapshot,
                tradePriceX96
            );
        }

        int192 globalFundingRateGrowthX96 = chooseFundingRateGrowthX96(_state.globalPosition, _parameter.side);
        int256 fundingFee = calculateFundingFee(
            globalFundingRateGrowthX96,
            positionCache.entryFundingRateGrowthX96,
            positionCache.size
        );

        int256 marginAfter = int256(uint256(positionCache.margin) + _parameter.marginDelta) + fundingFee;

        uint160 entryPriceAfterX96 = calculateNextEntryPriceX96(
            _parameter.side,
            positionCache.size,
            positionCache.entryPriceX96,
            _parameter.sizeDelta,
            tradePriceX96
        );

        _validatePositionLiquidateMaintainMarginRate(
            baseCfg,
            MaintainMarginRateParameter({
                margin: marginAfter,
                side: _parameter.side,
                size: sizeAfter,
                entryPriceX96: entryPriceAfterX96,
                decreasePriceX96: MarketUtil.chooseDecreaseIndexPriceX96(
                    _parameter.priceFeed,
                    _parameter.market,
                    _parameter.side
                ),
                liquidatablePosition: false
            })
        );
        uint128 marginAfterUint128 = uint256(marginAfter).toUint128();

        if (_parameter.sizeDelta > 0) {
            MarketUtil.validateLeverage(
                marginAfterUint128,
                calculateLiquidity(sizeAfter, entryPriceAfterX96),
                baseCfg.maxLeveragePerPosition
            );
            _increaseGlobalPosition(_state.globalPosition, _parameter.side, _parameter.sizeDelta);
        }

        IMarketManager.Position storage position = _state.positions[_parameter.account][_parameter.side];
        position.margin = marginAfterUint128;
        position.size = sizeAfter;
        position.entryPriceX96 = entryPriceAfterX96;
        position.entryFundingRateGrowthX96 = globalFundingRateGrowthX96;
        emit IMarketPosition.PositionIncreased(
            _parameter.market,
            _parameter.account,
            _parameter.side,
            _parameter.marginDelta,
            marginAfterUint128,
            sizeAfter,
            tradePriceX96,
            entryPriceAfterX96,
            fundingFee
        );

        // If the position is newly created, set the entry time
        if (positionCache.size == 0) position.entryTime = block.timestamp.toUint64();
    }

    function decreasePosition(
        IMarketManager.State storage _state,
        IConfigurable.MarketConfig storage _marketCfg,
        DecreasePositionParameter memory _parameter
    ) public returns (uint160 tradePriceX96, bool useEntryPriceAsTradePrice, uint128 adjustedMarginDelta) {
        IMarketManager.Position memory positionCache = _state.positions[_parameter.account][_parameter.side];
        if (positionCache.size == 0) revert IMarketErrors.PositionNotFound(_parameter.account, _parameter.side);

        if (positionCache.size < _parameter.sizeDelta)
            revert IMarketErrors.InsufficientSizeToDecrease(positionCache.size, _parameter.sizeDelta);

        uint160 decreaseIndexPriceX96 = MarketUtil.chooseDecreaseIndexPriceX96(
            _parameter.priceFeed,
            _parameter.market,
            _parameter.side
        );

        uint128 sizeAfter = positionCache.size;
        int256 realizedPnLDelta;
        uint160 actualTradePriceX96;
        if (_parameter.sizeDelta > 0) {
            // never underflow because of the validation above
            // prettier-ignore
            unchecked { sizeAfter -= _parameter.sizeDelta; }

            uint136 netSizeSnapshot = MarketUtil.globalLiquidityPositionNetSize(_state.globalLiquidityPosition);

            IConfigurable.MarketPriceConfig storage priceConfig = _marketCfg.priceConfig;
            tradePriceX96 = PriceUtil.updatePriceState(
                _state.globalLiquidityPosition,
                _state.priceState,
                PriceUtil.UpdatePriceStateParameter({
                    market: _parameter.market,
                    side: _parameter.side.flip(),
                    sizeDelta: _parameter.sizeDelta,
                    indexPriceX96: decreaseIndexPriceX96,
                    liquidationVertexIndex: _marketCfg.priceConfig.liquidationVertexIndex,
                    liquidation: false,
                    dynamicDepthMode: priceConfig.dynamicDepthMode,
                    dynamicDepthLevel: priceConfig.dynamicDepthLevel
                })
            );

            unchecked {
                if (
                    uint256(positionCache.entryTime) + _parameter.minProfitDuration > block.timestamp &&
                    hasUnrealizedProfit(_parameter.side, positionCache.entryPriceX96, tradePriceX96)
                ) {
                    useEntryPriceAsTradePrice = true;
                    actualTradePriceX96 = tradePriceX96;
                    tradePriceX96 = positionCache.entryPriceX96;
                }
            }

            _initializeAndSettleLiquidityUnrealizedPnL(
                _state.globalLiquidityPosition,
                _parameter.market,
                netSizeSnapshot,
                tradePriceX96
            );

            realizedPnLDelta = calculateUnrealizedPnL(
                _parameter.side,
                _parameter.sizeDelta,
                positionCache.entryPriceX96,
                tradePriceX96
            );
        }

        int192 globalFundingRateGrowthX96 = chooseFundingRateGrowthX96(_state.globalPosition, _parameter.side);
        int256 fundingFee = calculateFundingFee(
            globalFundingRateGrowthX96,
            positionCache.entryFundingRateGrowthX96,
            positionCache.size
        );

        int256 marginAfter = int256(uint256(positionCache.margin));
        marginAfter += realizedPnLDelta + fundingFee - int256(uint256(_parameter.marginDelta));
        if (marginAfter < 0) revert IMarketErrors.InsufficientMargin();

        uint128 marginAfterUint128 = uint256(marginAfter).toUint128();
        if (sizeAfter > 0) {
            IConfigurable.MarketBaseConfig storage baseCfg = _marketCfg.baseConfig;
            _validatePositionLiquidateMaintainMarginRate(
                baseCfg,
                MaintainMarginRateParameter({
                    margin: marginAfter,
                    side: _parameter.side,
                    size: sizeAfter,
                    entryPriceX96: positionCache.entryPriceX96,
                    decreasePriceX96: decreaseIndexPriceX96,
                    liquidatablePosition: false
                })
            );
            if (_parameter.marginDelta > 0)
                MarketUtil.validateLeverage(
                    marginAfterUint128,
                    calculateLiquidity(sizeAfter, positionCache.entryPriceX96),
                    baseCfg.maxLeveragePerPosition
                );

            // Update position
            IMarketManager.Position storage position = _state.positions[_parameter.account][_parameter.side];
            position.margin = marginAfterUint128;
            position.size = sizeAfter;
            position.entryFundingRateGrowthX96 = globalFundingRateGrowthX96;
        } else {
            // If the position is closed, the marginDelta needs to be added back to ensure that the
            // remaining margin of the position is 0.
            _parameter.marginDelta += marginAfterUint128;
            marginAfterUint128 = 0;

            // Delete position
            delete _state.positions[_parameter.account][_parameter.side];
        }

        adjustedMarginDelta = _parameter.marginDelta;

        if (_parameter.sizeDelta > 0)
            _decreaseGlobalPosition(_state.globalPosition, _parameter.side, _parameter.sizeDelta);

        emit IMarketPosition.PositionDecreased(
            _parameter.market,
            _parameter.account,
            _parameter.side,
            adjustedMarginDelta,
            marginAfterUint128,
            sizeAfter,
            tradePriceX96,
            realizedPnLDelta,
            fundingFee,
            _parameter.receiver
        );

        if (useEntryPriceAsTradePrice)
            emit IMarketPosition.PositionDecreasedByEntryPrice(
                _parameter.market,
                _parameter.account,
                _parameter.side,
                actualTradePriceX96
            );
    }

    function liquidatePosition(
        IMarketManager.State storage _state,
        IConfigurable.MarketConfig storage _marketCfg,
        LiquidatePositionParameter memory _parameter
    ) public {
        IMarketManager.Position memory positionCache = _state.positions[_parameter.account][_parameter.side];
        if (positionCache.size == 0) revert IMarketErrors.PositionNotFound(_parameter.account, _parameter.side);

        uint160 decreaseIndexPriceX96 = MarketUtil.chooseDecreaseIndexPriceX96(
            _parameter.priceFeed,
            _parameter.market,
            _parameter.side
        );

        int256 requiredFundingFee = calculateFundingFee(
            chooseFundingRateGrowthX96(_state.globalPosition, _parameter.side),
            positionCache.entryFundingRateGrowthX96,
            positionCache.size
        );

        _validatePositionLiquidateMaintainMarginRate(
            _marketCfg.baseConfig,
            MaintainMarginRateParameter({
                margin: int256(uint256(positionCache.margin)) + requiredFundingFee,
                side: _parameter.side,
                size: positionCache.size,
                entryPriceX96: positionCache.entryPriceX96,
                decreasePriceX96: decreaseIndexPriceX96,
                liquidatablePosition: true
            })
        );

        uint136 netSizeSnapshot = MarketUtil.globalLiquidityPositionNetSize(_state.globalLiquidityPosition);

        // try to update price state
        IConfigurable.MarketPriceConfig storage priceConfig = _marketCfg.priceConfig;
        uint160 tradePriceX96 = PriceUtil.updatePriceState(
            _state.globalLiquidityPosition,
            _state.priceState,
            PriceUtil.UpdatePriceStateParameter({
                market: _parameter.market,
                side: _parameter.side.flip(),
                sizeDelta: positionCache.size,
                indexPriceX96: decreaseIndexPriceX96,
                liquidationVertexIndex: _marketCfg.priceConfig.liquidationVertexIndex,
                liquidation: true,
                dynamicDepthMode: priceConfig.dynamicDepthMode,
                dynamicDepthLevel: priceConfig.dynamicDepthLevel
            })
        );

        _initializeAndSettleLiquidityUnrealizedPnL(
            _state.globalLiquidityPosition,
            _parameter.market,
            netSizeSnapshot,
            tradePriceX96
        );

        liquidatePosition(
            _state,
            _marketCfg,
            positionCache,
            LiquidateParameter({
                market: _parameter.market,
                account: _parameter.account,
                side: _parameter.side,
                tradePriceX96: tradePriceX96,
                decreaseIndexPriceX96: decreaseIndexPriceX96,
                requiredFundingFee: requiredFundingFee,
                feeReceiver: _parameter.feeReceiver
            })
        );
    }

    function liquidatePosition(
        IMarketManager.State storage _state,
        IConfigurable.MarketConfig storage _marketCfg,
        IMarketManager.Position memory _positionCache,
        LiquidateParameter memory _parameter
    ) internal {
        IConfigurable.MarketBaseConfig storage baseCfg = _marketCfg.baseConfig;
        (uint64 liquidationExecutionFee, uint32 liquidationFeeRate) = (
            baseCfg.liquidationExecutionFee,
            baseCfg.liquidationFeeRatePerPosition
        );
        (uint160 liquidationPriceX96, int256 adjustedFundingFee) = calculateLiquidationPriceX96(
            _positionCache,
            _parameter.side,
            _parameter.requiredFundingFee,
            liquidationFeeRate,
            liquidationExecutionFee
        );

        uint128 liquidationFee = calculateLiquidationFee(
            _positionCache.size,
            _positionCache.entryPriceX96,
            liquidationFeeRate
        );
        int256 liquidationFundDelta = int256(uint256(liquidationFee));

        if (_parameter.requiredFundingFee != adjustedFundingFee)
            liquidationFundDelta += _adjustFundingRateByLiquidation(
                _state,
                _parameter.market,
                _parameter.side,
                _parameter.requiredFundingFee,
                adjustedFundingFee
            );

        // If the liquidation price is different from the trade price,
        // the funds of the difference need to be transferred
        liquidationFundDelta += calculateUnrealizedPnL(
            _parameter.side,
            _positionCache.size,
            liquidationPriceX96,
            _parameter.tradePriceX96
        );

        IMarketManager.GlobalLiquidationFund storage globalLiquidationFund = _state.globalLiquidationFund;
        int256 liquidationFundAfter = globalLiquidationFund.liquidationFund + liquidationFundDelta;
        globalLiquidationFund.liquidationFund = liquidationFundAfter;
        emit IMarketManager.GlobalLiquidationFundIncreasedByLiquidation(
            _parameter.market,
            liquidationFundDelta,
            liquidationFundAfter
        );

        _decreaseGlobalPosition(_state.globalPosition, _parameter.side, _positionCache.size);

        delete _state.positions[_parameter.account][_parameter.side];

        emit IMarketPosition.PositionLiquidated(
            _parameter.market,
            msg.sender,
            _parameter.account,
            _parameter.side,
            _parameter.decreaseIndexPriceX96,
            _parameter.tradePriceX96,
            liquidationPriceX96,
            adjustedFundingFee,
            liquidationFee,
            liquidationExecutionFee,
            _parameter.feeReceiver
        );
    }

    /// @notice Calculate the next entry price of a position
    /// @param _side The side of the position (Long or Short)
    /// @param _sizeBefore The size of the position before the trade
    /// @param _entryPriceBeforeX96 The entry price of the position before the trade, as a Q64.96
    /// @param _sizeDelta The size of the trade
    /// @param _tradePriceX96 The price of the trade, as a Q64.96
    /// @return nextEntryPriceX96 The entry price of the position after the trade, as a Q64.96
    function calculateNextEntryPriceX96(
        Side _side,
        uint128 _sizeBefore,
        uint160 _entryPriceBeforeX96,
        uint128 _sizeDelta,
        uint160 _tradePriceX96
    ) internal pure returns (uint160 nextEntryPriceX96) {
        if ((_sizeBefore | _sizeDelta) == 0) nextEntryPriceX96 = 0;
        else if (_sizeBefore == 0) nextEntryPriceX96 = _tradePriceX96;
        else if (_sizeDelta == 0) nextEntryPriceX96 = _entryPriceBeforeX96;
        else {
            uint256 liquidityAfterX96 = uint256(_sizeBefore) * _entryPriceBeforeX96;
            liquidityAfterX96 += uint256(_sizeDelta) * _tradePriceX96;
            unchecked {
                uint256 sizeAfter = uint256(_sizeBefore) + _sizeDelta;
                nextEntryPriceX96 = (
                    _side.isLong() ? Math.ceilDiv(liquidityAfterX96, sizeAfter) : liquidityAfterX96 / sizeAfter
                ).toUint160();
            }
        }
    }

    /// @notice Calculate the liquidity (value) of a position
    /// @param _size The size of the position
    /// @param _priceX96 The trade price, as a Q64.96
    /// @return liquidity The liquidity (value) of the position
    function calculateLiquidity(uint128 _size, uint160 _priceX96) internal pure returns (uint128 liquidity) {
        liquidity = Math.mulDivUp(_size, _priceX96, Constants.Q96).toUint128();
    }

    /// @notice Check if a position has unrealized profit
    function hasUnrealizedProfit(
        Side _side,
        uint160 _entryPriceX96,
        uint160 _tradePriceX96
    ) internal pure returns (bool) {
        return _side.isLong() ? _tradePriceX96 > _entryPriceX96 : _tradePriceX96 < _entryPriceX96;
    }

    /// @dev Calculate the unrealized PnL of a position based on entry price
    /// @param _side The side of the position (Long or Short)
    /// @param _size The size of the position
    /// @param _entryPriceX96 The entry price of the position, as a Q64.96
    /// @param _priceX96 The trade price or index price, as a Q64.96
    /// @return unrealizedPnL The unrealized PnL of the position, positive value means profit,
    /// negative value means loss
    function calculateUnrealizedPnL(
        Side _side,
        uint128 _size,
        uint160 _entryPriceX96,
        uint160 _priceX96
    ) internal pure returns (int256 unrealizedPnL) {
        unchecked {
            // Because the maximum value of size is type(uint128).max, and the maximum value of entryPriceX96 and
            // priceX96 is type(uint160).max, so the maximum value of
            //      size * (entryPriceX96 - priceX96) / Q96
            // is type(uint192).max, so it is safe to convert the type to int256.
            if (_side.isLong()) {
                if (_entryPriceX96 > _priceX96)
                    unrealizedPnL = -int256(Math.mulDivUp(_size, _entryPriceX96 - _priceX96, Constants.Q96));
                else unrealizedPnL = int256(Math.mulDiv(_size, _priceX96 - _entryPriceX96, Constants.Q96));
            } else {
                if (_entryPriceX96 < _priceX96)
                    unrealizedPnL = -int256(Math.mulDivUp(_size, _priceX96 - _entryPriceX96, Constants.Q96));
                else unrealizedPnL = int256(Math.mulDiv(_size, _entryPriceX96 - _priceX96, Constants.Q96));
            }
        }
    }

    function chooseFundingRateGrowthX96(
        IMarketManager.GlobalPosition storage _globalPosition,
        Side _side
    ) internal view returns (int192) {
        return _side.isLong() ? _globalPosition.longFundingRateGrowthX96 : _globalPosition.shortFundingRateGrowthX96;
    }

    /// @notice Calculate the liquidation fee of a position
    /// @param _size The size of the position
    /// @param _entryPriceX96 The entry price of the position, as a Q64.96
    /// @param _liquidationFeeRate The liquidation fee rate for trader positions,
    /// denominated in ten thousandths of a bip (i.e. 1e-8)
    /// @return liquidationFee The liquidation fee of the position
    function calculateLiquidationFee(
        uint128 _size,
        uint160 _entryPriceX96,
        uint32 _liquidationFeeRate
    ) internal pure returns (uint128 liquidationFee) {
        unchecked {
            uint256 denominator = Constants.BASIS_POINTS_DIVISOR * Constants.Q96;
            liquidationFee = Math
                .mulDivUp(uint256(_size) * _liquidationFeeRate, _entryPriceX96, denominator)
                .toUint128();
        }
    }

    /// @notice Calculate the funding fee of a position
    /// @param _globalFundingRateGrowthX96 The global funding rate growth, as a Q96.96
    /// @param _positionFundingRateGrowthX96 The position funding rate growth, as a Q96.96
    /// @param _positionSize The size of the position
    /// @return fundingFee The funding fee of the position, a positive value means the position receives
    /// funding fee, while a negative value means the position pays funding fee
    function calculateFundingFee(
        int192 _globalFundingRateGrowthX96,
        int192 _positionFundingRateGrowthX96,
        uint128 _positionSize
    ) internal pure returns (int256 fundingFee) {
        int256 deltaX96 = _globalFundingRateGrowthX96 - _positionFundingRateGrowthX96;
        if (deltaX96 >= 0) fundingFee = Math.mulDiv(uint256(deltaX96), _positionSize, Constants.Q96).toInt256();
        else fundingFee = -Math.mulDivUp(uint256(-deltaX96), _positionSize, Constants.Q96).toInt256();
    }

    /// @notice Calculate the maintenance margin
    /// @dev maintenanceMargin = size * entryPrice * liquidationFeeRate
    ///                          + liquidationExecutionFee
    /// @param _size The size of the position
    /// @param _entryPriceX96 The entry price of the position, as a Q64.96
    /// @param _liquidationFeeRate The liquidation fee rate for trader positions,
    /// denominated in ten thousandths of a bip (i.e. 1e-8)
    /// @param _liquidationExecutionFee The liquidation execution fee paid by the position
    /// @return maintenanceMargin The maintenance margin
    function calculateMaintenanceMargin(
        uint128 _size,
        uint160 _entryPriceX96,
        uint32 _liquidationFeeRate,
        uint64 _liquidationExecutionFee
    ) internal pure returns (uint256 maintenanceMargin) {
        unchecked {
            maintenanceMargin = Math.mulDivUp(
                _size,
                uint256(_entryPriceX96) * _liquidationFeeRate,
                Constants.BASIS_POINTS_DIVISOR * Constants.Q96
            );
            // Because the maximum value of size is type(uint128).max, and the maximum value of entryPriceX96
            // is type(uint160).max, and liquidationFeeRate is at most DIVISOR,
            // so the maximum value of
            //      size * entryPriceX96 * liquidationFeeRate / (Q96 * DIVISOR)
            // is type(uint192).max, so there will be no overflow here.
            maintenanceMargin += _liquidationExecutionFee;
        }
    }

    /// @notice calculate the liquidation price
    /// @param _positionCache The cache of position
    /// @param _side The side of the position (Long or Short)
    /// @param _fundingFee The funding fee, a positive value means the position receives a funding fee,
    /// while a negative value means the position pays funding fee
    /// @param _liquidationFeeRate The liquidation fee rate for trader positions,
    /// denominated in ten thousandths of a bip (i.e. 1e-8)
    /// @param _liquidationExecutionFee The liquidation execution fee paid by the position
    /// @return liquidationPriceX96 The liquidation price of the position, as a Q64.96
    /// @return adjustedFundingFee The liquidation price based on the funding fee. If `_fundingFee` is negative,
    /// then this value is not less than `_fundingFee`
    function calculateLiquidationPriceX96(
        IMarketManager.Position memory _positionCache,
        Side _side,
        int256 _fundingFee,
        uint32 _liquidationFeeRate,
        uint64 _liquidationExecutionFee
    ) internal pure returns (uint160 liquidationPriceX96, int256 adjustedFundingFee) {
        int256 marginInt256 = int256(uint256(_positionCache.margin));
        if ((marginInt256 + _fundingFee) > 0) {
            liquidationPriceX96 = _calculateLiquidationPriceX96(
                _positionCache,
                _side,
                _fundingFee,
                _liquidationFeeRate,
                _liquidationExecutionFee
            );
            if (_isAcceptableLiquidationPriceX96(_side, liquidationPriceX96, _positionCache.entryPriceX96))
                return (liquidationPriceX96, _fundingFee);
        }

        adjustedFundingFee = _fundingFee;

        if (adjustedFundingFee < 0) {
            adjustedFundingFee = 0;
            liquidationPriceX96 = _calculateLiquidationPriceX96(
                _positionCache,
                _side,
                adjustedFundingFee,
                _liquidationFeeRate,
                _liquidationExecutionFee
            );
        }
    }

    function _isAcceptableLiquidationPriceX96(
        Side _side,
        uint160 _liquidationPriceX96,
        uint160 _entryPriceX96
    ) private pure returns (bool) {
        return
            (_side.isLong() && _liquidationPriceX96 < _entryPriceX96) ||
            (_side.isShort() && _liquidationPriceX96 > _entryPriceX96);
    }

    /// @notice Calculate the liquidation price
    /// @dev Given the liquidation condition as:
    /// For long position: margin + fundingFee - positionSize * (entryPrice - liquidationPrice)
    ///                     = entryPrice * positionSize * liquidationFeeRate + liquidationExecutionFee
    /// For short position: margin + fundingFee - positionSize * (liquidationPrice - entryPrice)
    ///                     = entryPrice * positionSize * liquidationFeeRate + liquidationExecutionFee
    /// @param _positionCache The cache of position
    /// @param _side The side of the position (Long or Short)
    /// @param _fundingFee The funding fee, a positive value means the position receives a funding fee,
    /// while a negative value means the position pays funding fee
    /// @param _liquidationFeeRate The liquidation fee rate for trader positions,
    /// denominated in ten thousandths of a bip (i.e. 1e-8)
    /// @param _liquidationExecutionFee The liquidation execution fee paid by the position
    /// @return liquidationPriceX96 The liquidation price of the position, as a Q64.96
    function _calculateLiquidationPriceX96(
        IMarketManager.Position memory _positionCache,
        Side _side,
        int256 _fundingFee,
        uint32 _liquidationFeeRate,
        uint64 _liquidationExecutionFee
    ) private pure returns (uint160 liquidationPriceX96) {
        int136 marginAfter = int136(uint136(_positionCache.margin)) + _fundingFee.toInt136();
        marginAfter -= int136(uint136(_liquidationExecutionFee));

        int256 step1X96;
        int256 step2X96;
        unchecked {
            uint32 feeRateDelta = _side.isLong()
                ? Constants.BASIS_POINTS_DIVISOR + _liquidationFeeRate
                : Constants.BASIS_POINTS_DIVISOR - _liquidationFeeRate;
            step1X96 = Math
                .mulDiv(
                    _positionCache.entryPriceX96,
                    feeRateDelta,
                    Constants.BASIS_POINTS_DIVISOR,
                    _side.isLong() ? Math.Rounding.Down : Math.Rounding.Up
                )
                .toInt256();

            if (marginAfter >= 0)
                step2X96 = int256(Math.ceilDiv(uint256(uint136(marginAfter)) << 96, _positionCache.size));
            else step2X96 = int256((uint256(uint144(-int144(marginAfter))) << 96) / _positionCache.size);
        }

        if (_side.isLong())
            liquidationPriceX96 = (step1X96 - (marginAfter >= 0 ? step2X96 : -step2X96)).toUint256().toUint160();
        else liquidationPriceX96 = (step1X96 + (marginAfter >= 0 ? step2X96 : -step2X96)).toUint256().toUint160();
    }

    function _validateIncreaseSize(
        IMarketManager.GlobalPosition storage _position,
        uint128 _sizeBefore,
        uint128 _sizeDelta
    ) private view returns (uint128 sizeAfter) {
        sizeAfter = _sizeBefore + _sizeDelta;
        if (sizeAfter > _position.maxSizePerPosition)
            revert IMarketErrors.SizeExceedsMaxSizePerPosition(sizeAfter, _position.maxSizePerPosition);

        uint128 totalSizeAfter = _position.longSize + _position.shortSize + _sizeDelta;
        if (totalSizeAfter > _position.maxSize)
            revert IMarketErrors.SizeExceedsMaxSize(totalSizeAfter, _position.maxSize);
    }

    function _validateGlobalLiquidity(uint128 _globalLiquidity) private pure {
        if (_globalLiquidity == 0) revert IMarketErrors.InsufficientGlobalLiquidity();
    }

    function _increaseGlobalPosition(
        IMarketManager.GlobalPosition storage _globalPosition,
        Side _side,
        uint128 _size
    ) private {
        unchecked {
            if (_side.isLong()) _globalPosition.longSize += _size;
            else _globalPosition.shortSize += _size;
        }
    }

    function _decreaseGlobalPosition(
        IMarketManager.GlobalPosition storage _globalPosition,
        Side _side,
        uint128 _size
    ) private {
        unchecked {
            if (_side.isLong()) _globalPosition.longSize -= _size;
            else _globalPosition.shortSize -= _size;
        }
    }

    function _adjustFundingRateByLiquidation(
        IMarketManager.State storage _state,
        IMarketDescriptor _market,
        Side _side,
        int256 _requiredFundingFee,
        int256 _adjustedFundingFee
    ) private returns (int256 liquidationFundLoss) {
        int256 insufficientFundingFee = _adjustedFundingFee - _requiredFundingFee;
        IMarketManager.GlobalPosition storage globalPosition = _state.globalPosition;
        uint128 oppositeSize = _side.isLong() ? globalPosition.shortSize : globalPosition.longSize;
        if (oppositeSize > 0) {
            int192 insufficientFundingRateGrowthDeltaX96 = Math
                .mulDiv(uint256(insufficientFundingFee), Constants.Q96, oppositeSize)
                .toInt256()
                .toInt192();
            int192 longFundingRateGrowthAfterX96 = globalPosition.longFundingRateGrowthX96;
            int192 shortFundingRateGrowthAfterX96 = globalPosition.shortFundingRateGrowthX96;
            if (_side.isLong()) shortFundingRateGrowthAfterX96 -= insufficientFundingRateGrowthDeltaX96;
            else longFundingRateGrowthAfterX96 -= insufficientFundingRateGrowthDeltaX96;
            FundingRateUtil.adjustFundingRate(
                _state,
                _market,
                longFundingRateGrowthAfterX96,
                shortFundingRateGrowthAfterX96
            );
        } else liquidationFundLoss = -insufficientFundingFee;
    }

    /// @notice Validate the position has not reached the liquidation margin rate
    function _validatePositionLiquidateMaintainMarginRate(
        IConfigurable.MarketBaseConfig storage _baseCfg,
        MaintainMarginRateParameter memory _parameter
    ) private view {
        int256 unrealizedPnL = calculateUnrealizedPnL(
            _parameter.side,
            _parameter.size,
            _parameter.entryPriceX96,
            _parameter.decreasePriceX96
        );
        uint256 maintenanceMargin = calculateMaintenanceMargin(
            _parameter.size,
            _parameter.entryPriceX96,
            _baseCfg.liquidationFeeRatePerPosition,
            _baseCfg.liquidationExecutionFee
        );
        int256 marginAfter = _parameter.margin + unrealizedPnL;
        if (!_parameter.liquidatablePosition) {
            if (_parameter.margin <= 0 || marginAfter <= 0 || maintenanceMargin >= uint256(marginAfter))
                revert IMarketErrors.MarginRateTooHigh(_parameter.margin, unrealizedPnL, maintenanceMargin);
        } else {
            if (_parameter.margin > 0 && marginAfter > 0 && maintenanceMargin < uint256(marginAfter))
                revert IMarketErrors.MarginRateTooLow(_parameter.margin, unrealizedPnL, maintenanceMargin);
        }
    }

    function _initializeAndSettleLiquidityUnrealizedPnL(
        IMarketManager.GlobalLiquidityPosition storage _position,
        IMarketDescriptor _market,
        uint136 _netSizeSnapshot,
        uint160 _tradePriceX96
    ) private {
        MarketUtil.initializePreviousSPPrice(_position, _market, _netSizeSnapshot, _tradePriceX96);
        MarketUtil.settleLiquidityUnrealizedPnL(_position, _market, _netSizeSnapshot, _tradePriceX96);
    }
}
