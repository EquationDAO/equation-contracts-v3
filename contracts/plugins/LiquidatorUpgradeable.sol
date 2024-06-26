// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.23;

import "./interfaces/ILiquidator.sol";
import "../core/MarketManagerUpgradeable.sol";

contract LiquidatorUpgradeable is ILiquidator, GovernableUpgradeable {
    using SafeERC20 for IERC20;

    RouterUpgradeable public router;
    MarketManagerUpgradeable public marketManager;
    IERC20 public usd;
    IPriceFeed public priceFeed;

    mapping(address => bool) public executors;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        RouterUpgradeable _router,
        MarketManagerUpgradeable _marketManager,
        IERC20 _usd
    ) public initializer {
        GovernableUpgradeable.__Governable_init();

        (router, marketManager, usd, priceFeed) = (_router, _marketManager, _usd, _marketManager.priceFeed());
    }

    /// @inheritdoc ILiquidator
    function updatePriceFeed() external override onlyGov {
        priceFeed = marketManager.priceFeed();
    }

    /// @inheritdoc ILiquidator
    function updateExecutor(address _account, bool _active) external override onlyGov {
        executors[_account] = _active;
        emit ExecutorUpdated(_account, _active);
    }

    /// @inheritdoc ILiquidator
    function liquidateLiquidityPosition(
        IMarketDescriptor _market,
        address _account,
        address _feeReceiver
    ) external override {
        _onlyExecutor();

        router.pluginLiquidateLiquidityPosition(_market, _account, _feeReceiver);
    }

    /// @inheritdoc ILiquidator
    function liquidatePosition(
        IMarketDescriptor _market,
        address _account,
        Side _side,
        address _feeReceiver
    ) external override {
        _onlyExecutor();

        uint160 decreaseIndexPriceX96 = MarketUtil.chooseDecreaseIndexPriceX96(priceFeed, _market, _side);
        IMarketPosition.Position memory position = marketManager.positions(_market, _account, _side);

        // Fast path, if the position is empty or there is no unrealized profit in the position,
        // liquidate the position directly

        if (
            position.size == 0 ||
            !PositionUtil.hasUnrealizedProfit(_side, position.entryPriceX96, decreaseIndexPriceX96)
        ) {
            router.pluginLiquidatePosition(_market, _account, _side, _feeReceiver);
            return;
        }

        // Slow path, if the position has unrealized profit, there is a possibility of liquidating
        // the position due to funding fee.
        // Therefore, attempt to close the position, if the closing fails, then liquidate the position directly

        router.pluginSettleFundingFee(_market);

        // Before closing, MUST verify that the position meets the liquidation conditions
        uint64 liquidationExecutionFee = _requireLiquidatable(_market, _side, position, decreaseIndexPriceX96);

        try router.pluginClosePositionByLiquidator(_market, _account, _side, position.size, address(this)) {
            // If the closing succeeds, transfer the liquidation execution fee to the fee receiver
            uint256 balance = usd.balanceOf(address(this));
            uint256 balanceRemaining;

            unchecked {
                (liquidationExecutionFee, balanceRemaining) = balance >= liquidationExecutionFee
                    ? (liquidationExecutionFee, balance - liquidationExecutionFee)
                    : (uint64(balance), 0);
            }

            usd.safeTransfer(_feeReceiver, liquidationExecutionFee);
            if (balanceRemaining > 0) usd.safeTransfer(_account, balanceRemaining);

            emit PositionClosedByLiquidator(_market, _account, _side, liquidationExecutionFee);
        } catch {
            router.pluginLiquidatePosition(_market, _account, _side, _feeReceiver);
        }
    }

    function _onlyExecutor() private view {
        if (!executors[msg.sender]) revert Forbidden();
    }

    /// @dev The function is similar to `PositionUtil#_validatePositionLiquidateMaintainMarginRate`
    function _requireLiquidatable(
        IMarketDescriptor _market,
        Side _side,
        IMarketManager.Position memory _position,
        uint160 _decreasePriceX96
    ) private view returns (uint64 liquidationExecutionFee) {
        IConfigurable.MarketBaseConfig memory baseCfg = marketManager.marketBaseConfigs(_market);
        liquidationExecutionFee = baseCfg.liquidationExecutionFee;

        uint256 maintenanceMargin = PositionUtil.calculateMaintenanceMargin(
            _position.size,
            _position.entryPriceX96,
            baseCfg.liquidationFeeRatePerPosition,
            liquidationExecutionFee
        );

        int256 fundingFee = PositionUtil.calculateFundingFee(
            _chooseFundingRateGrowthX96(_market, _side),
            _position.entryFundingRateGrowthX96,
            _position.size
        );
        int256 margin = int256(uint256(_position.margin)) + fundingFee;
        int256 unrealizedPnL = PositionUtil.calculateUnrealizedPnL(
            _side,
            _position.size,
            _position.entryPriceX96,
            _decreasePriceX96
        );

        int256 marginAfter = margin + unrealizedPnL;
        if (margin > 0 && marginAfter > 0 && maintenanceMargin < uint256(marginAfter))
            revert IMarketErrors.MarginRateTooLow(margin, unrealizedPnL, maintenanceMargin);
    }

    function _chooseFundingRateGrowthX96(IMarketDescriptor _market, Side _side) private view returns (int192) {
        IMarketPosition.GlobalPosition memory globalPosition = marketManager.globalPositions(_market);
        return _side.isLong() ? globalPosition.longFundingRateGrowthX96 : globalPosition.shortFundingRateGrowthX96;
    }
}
