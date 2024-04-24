// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../governance/GovernableUpgradeable.sol";
import "../libraries/ConfigurableUtil.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

abstract contract ConfigurableUpgradeable is IConfigurable, GovernableUpgradeable, ReentrancyGuardUpgradeable {
    using ConfigurableUtil for mapping(IMarketDescriptor market => MarketConfig);

    /// @custom:storage-location erc7201:EquationDAO.storage.ConfigurableUpgradeable
    struct ConfigurableStorage {
        IERC20 usd;
        mapping(IMarketDescriptor market => MarketConfig) marketConfigs;
    }

    // keccak256(abi.encode(uint256(keccak256("EquationDAO.storage.ConfigurableUpgradeable")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant CONFIGURABLE_UPGRADEABLE_STORAGE =
        0x3615454e95df0a9824efb96d9292cf1267183eea5f0490c9e2cf1c558c6eda00;

    function __Configurable_init(IERC20 _usd) internal onlyInitializing {
        __ReentrancyGuard_init();
        __Governable_init();
        __Configurable_init_unchained(_usd);
    }

    function __Configurable_init_unchained(IERC20 _usd) internal onlyInitializing {
        _configurableStorage().usd = _usd;
    }

    /// @inheritdoc IConfigurable
    function USD() public view override returns (IERC20) {
        return _configurableStorage().usd;
    }

    /// @inheritdoc IConfigurable
    function marketBaseConfigs(IMarketDescriptor _market) external view override returns (MarketBaseConfig memory) {
        return _configurableStorage().marketConfigs[_market].baseConfig;
    }

    /// @inheritdoc IConfigurable
    function marketFeeRateConfigs(
        IMarketDescriptor _market
    ) external view override returns (MarketFeeRateConfig memory) {
        return _configurableStorage().marketConfigs[_market].feeRateConfig;
    }

    /// @inheritdoc IConfigurable
    function isEnabledMarket(IMarketDescriptor _market) external view override returns (bool) {
        return _isEnabledMarket(_market);
    }

    /// @inheritdoc IConfigurable
    function marketPriceConfigs(IMarketDescriptor _market) external view override returns (MarketPriceConfig memory) {
        return _configurableStorage().marketConfigs[_market].priceConfig;
    }

    /// @inheritdoc IConfigurable
    function marketPriceVertexConfigs(
        IMarketDescriptor _market,
        uint8 _index
    ) external view override returns (VertexConfig memory) {
        return _configurableStorage().marketConfigs[_market].priceConfig.vertices[_index];
    }

    /// @inheritdoc IConfigurable
    function enableMarket(IMarketDescriptor _market, MarketConfig calldata _cfg) external override nonReentrant {
        _onlyGov();
        _configurableStorage().marketConfigs.enableMarket(_market, _cfg);

        afterMarketEnabled(_market);
    }

    /// @inheritdoc IConfigurable
    function updateMarketBaseConfig(
        IMarketDescriptor _market,
        MarketBaseConfig calldata _newCfg
    ) external override nonReentrant {
        _onlyGov();
        MarketBaseConfig storage oldCfg = _configurableStorage().marketConfigs[_market].baseConfig;
        bytes32 oldHash = keccak256(
            abi.encode(oldCfg.maxPositionLiquidity, oldCfg.maxPositionValueRate, oldCfg.maxSizeRatePerPosition)
        );
        _configurableStorage().marketConfigs.updateMarketBaseConfig(_market, _newCfg);
        bytes32 newHash = keccak256(
            abi.encode(_newCfg.maxPositionLiquidity, _newCfg.maxPositionValueRate, _newCfg.maxSizeRatePerPosition)
        );

        // If the hash has changed, it means that the maximum available size needs to be recalculated
        if (oldHash != newHash) afterMarketBaseConfigChanged(_market);
    }

    /// @inheritdoc IConfigurable
    function updateMarketFeeRateConfig(
        IMarketDescriptor _market,
        MarketFeeRateConfig calldata _newCfg
    ) external override nonReentrant {
        _onlyGov();
        _configurableStorage().marketConfigs.updateMarketFeeRateConfig(_market, _newCfg);
    }

    /// @inheritdoc IConfigurable
    function updateMarketPriceConfig(
        IMarketDescriptor _market,
        MarketPriceConfig calldata _newCfg
    ) external override nonReentrant {
        _onlyGov();
        _configurableStorage().marketConfigs.updateMarketPriceConfig(_market, _newCfg);

        afterMarketPriceConfigChanged(_market);
    }

    function afterMarketEnabled(IMarketDescriptor _market) internal virtual {
        // solhint-disable-previous-line no-empty-blocks
    }

    /// @dev The first time the market is enabled, this function does not need to be called
    function afterMarketBaseConfigChanged(IMarketDescriptor _market) internal virtual {
        // solhint-disable-previous-line no-empty-blocks
    }

    /// @dev The first time the market is enabled, this function does not need to be called
    function afterMarketPriceConfigChanged(IMarketDescriptor _market) internal virtual {
        // solhint-disable-previous-line no-empty-blocks
    }

    function _isEnabledMarket(IMarketDescriptor _market) internal view returns (bool) {
        return _configurableStorage().marketConfigs[_market].baseConfig.maxLeveragePerLiquidityPosition != 0;
    }

    function _configurableStorage() internal pure returns (ConfigurableStorage storage $) {
        // prettier-ignore
        assembly { $.slot := CONFIGURABLE_UPGRADEABLE_STORAGE }
    }
}
