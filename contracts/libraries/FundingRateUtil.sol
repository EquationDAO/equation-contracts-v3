// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.23;

import "./MarketUtil.sol";

/// @notice Utility library for calculating funding rates
library FundingRateUtil {
    using SafeCast for *;

    /// @notice Adjust the funding rate
    /// @param _state The state of the market
    /// @param _market The descriptor used to describe the metadata of the market, such as symbol, name, decimals
    /// @param _longFundingRateGrowthAfterX96 The long funding rate growth after the funding rate is updated,
    /// as a Q96.96
    /// @param _shortFundingRateGrowthAfterX96 The short funding rate growth after the funding rate is updated,
    /// as a Q96.96
    function adjustFundingRate(
        IMarketManager.State storage _state,
        IMarketDescriptor _market,
        int192 _longFundingRateGrowthAfterX96,
        int192 _shortFundingRateGrowthAfterX96
    ) internal {
        _state.globalPosition.longFundingRateGrowthX96 = _longFundingRateGrowthAfterX96;
        _state.globalPosition.shortFundingRateGrowthX96 = _shortFundingRateGrowthAfterX96;
        emit IMarketPosition.FundingFeeSettled(
            _market,
            _longFundingRateGrowthAfterX96,
            _shortFundingRateGrowthAfterX96
        );
    }

    /// @notice Settle the funding fee
    function settleFundingFee(
        IMarketManager.State storage _state,
        IConfigurable.MarketConfig storage _cfg,
        IPriceFeed _priceFeed,
        IMarketDescriptor _market
    ) public {
        uint64 currentTimestamp = block.timestamp.toUint64();
        IMarketManager.GlobalPosition storage _globalPosition = _state.globalPosition;
        uint64 lastFundingFeeSettleTime = _globalPosition.lastFundingFeeSettleTime;
        if (lastFundingFeeSettleTime == currentTimestamp) return;

        (uint128 longSize, uint128 shortSize) = (_globalPosition.longSize, _globalPosition.shortSize);
        IMarketManager.GlobalLiquidityPosition storage _globalLiquidityPosition = _state.globalLiquidityPosition;
        // Ignore funding fees if there is no liquidity or no user position
        if (_globalLiquidityPosition.liquidity == 0 || (longSize | shortSize) == 0) {
            _globalPosition.lastFundingFeeSettleTime = currentTimestamp;
            emit IMarketPosition.FundingFeeSettled(
                _market,
                _globalPosition.longFundingRateGrowthX96,
                _globalPosition.shortFundingRateGrowthX96
            );
            return;
        }

        uint160 indexPriceX96 = _priceFeed.getMaxPriceX96(_market);
        IConfigurable.MarketFeeRateConfig memory feeRateCfgCache = _cfg.feeRateConfig;
        uint64 timeDelta = currentTimestamp - lastFundingFeeSettleTime;
        // actualPremiumRate = marketPrice / indexPrice - 1
        //                   = (indexPrice + premiumRate * basisIndexPrice) / indexPrice - 1
        //                   = premiumRate * basisIndexPrice / indexPrice
        IMarketManager.PriceState storage priceState = _state.priceState;
        uint128 actualPremiumRateX96 = Math
            .mulDivUp(priceState.premiumRateX96, priceState.basisIndexPriceX96, indexPriceX96)
            .toUint128();
        int192 baseRateX96 = calculateBaseRateX96(
            feeRateCfgCache,
            longSize,
            shortSize,
            actualPremiumRateX96,
            timeDelta
        );

        (int256 longFundingFee, int256 shortFundingFee, uint256 liquidityFundingFee) = settleProtocolFundingFee(
            _state,
            feeRateCfgCache,
            _market,
            longSize,
            shortSize,
            indexPriceX96,
            timeDelta
        );

        (uint128 paidSize, uint128 receivedSize, uint256 paidFundingRateX96) = baseRateX96 >= 0
            ? (longSize, shortSize, uint256(int256(baseRateX96)))
            : (shortSize, longSize, uint256(-int256(baseRateX96)));

        if (paidSize > 0 && baseRateX96 != 0) {
            uint256 paidLiquidity = Math.mulDivUp(paidSize, indexPriceX96, Constants.Q96);
            int256 paidFundingFee = Math.mulDivUp(paidLiquidity, paidFundingRateX96, Constants.Q96).toInt256();

            int256 receivedFundingFee = paidFundingFee;
            if (paidSize > receivedSize) {
                uint256 liquidityFundingFee2;
                unchecked {
                    liquidityFundingFee2 = Math.mulDiv(paidSize - receivedSize, uint256(paidFundingFee), paidSize);
                    receivedFundingFee = receivedSize == 0
                        ? int256(0)
                        : (paidFundingFee - int256(liquidityFundingFee2));
                }

                liquidityFundingFee += liquidityFundingFee2;
            }

            if (baseRateX96 >= 0) {
                longFundingFee = -longFundingFee - paidFundingFee;
                shortFundingFee = -shortFundingFee + receivedFundingFee;
            } else {
                longFundingFee = -longFundingFee + receivedFundingFee;
                shortFundingFee = -shortFundingFee - paidFundingFee;
            }
        }

        uint256 unrealizedPnLGrowthDeltaX64 = (uint256(liquidityFundingFee.toUint128()) << 64) /
            _globalLiquidityPosition.liquidity;
        int256 unrealizedPnLGrowthAfterX64 = _globalLiquidityPosition.unrealizedPnLGrowthX64 +
            unrealizedPnLGrowthDeltaX64.toInt256();
        _globalLiquidityPosition.unrealizedPnLGrowthX64 = unrealizedPnLGrowthAfterX64.toInt192();
        emit IMarketLiquidityPosition.GlobalLiquidityPositionPnLGrowthIncreasedByFundingFee(
            _market,
            unrealizedPnLGrowthAfterX64
        );

        int192 longFundingRateGrowthDeltaX96 = calculateFundingRateGrowthDeltaX96(longFundingFee, longSize);
        int192 shortFundingRateGrowthDeltaX96 = calculateFundingRateGrowthDeltaX96(shortFundingFee, shortSize);

        int192 longFundingRateGrowthX96 = _globalPosition.longFundingRateGrowthX96 + longFundingRateGrowthDeltaX96;
        int192 shortFundingRateGrowthX96 = _globalPosition.shortFundingRateGrowthX96 + shortFundingRateGrowthDeltaX96;
        _globalPosition.lastFundingFeeSettleTime = currentTimestamp;
        adjustFundingRate(_state, _market, longFundingRateGrowthX96, shortFundingRateGrowthX96);
    }

    function calculateFundingRateGrowthDeltaX96(
        int256 _fundingFee,
        uint128 _size
    ) internal pure returns (int192 deltaX96) {
        if (_size == 0) return int192(0);

        unchecked {
            (uint256 fundingFeeAbs, Math.Rounding rounding) = _fundingFee >= 0
                ? (uint256(_fundingFee), Math.Rounding.Down)
                : (uint256(-_fundingFee), Math.Rounding.Up);
            deltaX96 = Math.mulDiv(fundingFeeAbs, Constants.Q96, _size, rounding).toInt256().toInt192();
        }

        deltaX96 = _fundingFee >= 0 ? deltaX96 : -deltaX96;
    }

    /// @notice Settle the protocol funding fee
    /// @return longFundingFee The long funding fee that should be paid to the protocol, always non-negative
    /// @return shortFundingFee The short funding fee that should be paid to the protocol, always non-negative
    /// @return liquidityFundingFee The funding fee that should be paid to the liquidity provider
    function settleProtocolFundingFee(
        IMarketManager.State storage _state,
        IConfigurable.MarketFeeRateConfig memory _feeRateCfgCache,
        IMarketDescriptor _market,
        uint128 _longSize,
        uint128 _shortSize,
        uint160 _indexPriceX96,
        uint64 _timeDelta
    ) internal returns (int256 longFundingFee, int256 shortFundingFee, uint256 liquidityFundingFee) {
        (uint256 longFundingRateX96, uint256 shortFundingRateX96) = calculateFundingRateX96(
            _feeRateCfgCache,
            _timeDelta
        );
        uint256 longLiquidity = Math.mulDivUp(_longSize, _indexPriceX96, Constants.Q96);
        longFundingFee = Math.mulDivUp(longLiquidity, longFundingRateX96, Constants.Q96).toInt256();

        uint256 shortLiquidity = Math.mulDivUp(_shortSize, _indexPriceX96, Constants.Q96);
        shortFundingFee = Math.mulDivUp(shortLiquidity, shortFundingRateX96, Constants.Q96).toInt256();

        uint256 totalProtocolFundingFee = uint256(longFundingFee) + uint256(shortFundingFee);
        liquidityFundingFee = Math.mulDiv(
            totalProtocolFundingFee,
            _feeRateCfgCache.liquidityFundingFeeRate,
            Constants.BASIS_POINTS_DIVISOR
        );
        unchecked {
            uint128 protocolFeeDelta = (totalProtocolFundingFee - liquidityFundingFee).toUint128();
            _state.protocolFee += protocolFeeDelta; // overflow is desired
            emit IMarketManager.ProtocolFeeIncreased(_market, protocolFeeDelta);
        }
    }

    /// @notice Calculate the funding rate that should be paid to the protocol
    /// @param _feeRateCfgCache The cache of the fee rate configuration
    /// @param _timeDelta The time delta between the last funding fee settlement and the current time
    /// @return longFundingRateX96 The long funding rate that should be paid to the protocol, as a Q96.96
    /// @return shortFundingRateX96 The short funding rate that should be paid to the protocol, as a Q96.96
    function calculateFundingRateX96(
        IConfigurable.MarketFeeRateConfig memory _feeRateCfgCache,
        uint64 _timeDelta
    ) internal pure returns (uint256 longFundingRateX96, uint256 shortFundingRateX96) {
        unchecked {
            // tempValueX96 is less than 1 << 146
            uint256 tempValueX96 = Math.ceilDiv(
                (uint256(_feeRateCfgCache.protocolFundingFeeRate) * _timeDelta) << 96,
                uint256(Constants.BASIS_POINTS_DIVISOR) * 8 hours
            );
            longFundingRateX96 = Math.ceilDiv(
                tempValueX96 * _feeRateCfgCache.protocolFundingCoeff,
                Constants.BASIS_POINTS_DIVISOR
            );

            shortFundingRateX96 = Math.ceilDiv(
                tempValueX96 * (Constants.BASIS_POINTS_DIVISOR - _feeRateCfgCache.protocolFundingCoeff),
                Constants.BASIS_POINTS_DIVISOR
            );
        }
    }

    /// @notice Calculate the base rate
    /// @return baseRateX96 The base rate, as a Q96.96.
    /// If the base rate is positive, it means that the LP holds a short position,
    /// otherwise it means that the LP holds a long position.
    function calculateBaseRateX96(
        IConfigurable.MarketFeeRateConfig memory _feeRateCfgCache,
        uint128 _longSize,
        uint128 _shortSize,
        uint128 _premiumRateX96,
        uint64 _timDelta
    ) internal pure returns (int192 baseRateX96) {
        int256 fundingX96;
        unchecked {
            int256 tempValueX96 = int256(uint256(_premiumRateX96) * _feeRateCfgCache.fundingCoeff);
            // LP holds a short position, it is a positive number, otherwise it is a negative number
            tempValueX96 = _longSize >= _shortSize ? tempValueX96 : -tempValueX96;
            fundingX96 = (int256(uint256(_feeRateCfgCache.interestRate) << 96)) - tempValueX96;

            int256 fundingBufferX96 = int256(uint256(_feeRateCfgCache.fundingBuffer) << 96);
            if (fundingX96 > fundingBufferX96) fundingX96 = fundingBufferX96;
            else if (fundingX96 < -fundingBufferX96) fundingX96 = -fundingBufferX96;

            fundingX96 = tempValueX96 + fundingX96;

            baseRateX96 = Math
                .mulDivUp(
                    fundingX96 <= 0 ? uint256(-fundingX96) : uint256(fundingX96),
                    _timDelta,
                    uint256(Constants.BASIS_POINTS_DIVISOR) * 8 hours
                )
                .toInt256()
                .toInt192();
        }

        baseRateX96 = fundingX96 > 0 ? baseRateX96 : -baseRateX96;
    }
}
