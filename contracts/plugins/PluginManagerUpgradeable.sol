// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.23;

import "../governance/GovernableUpgradeable.sol";
import "./interfaces/IPluginManager.sol";

abstract contract PluginManagerUpgradeable is IPluginManager, GovernableUpgradeable {
    /// @custom:storage-location erc7201:EquationDAO.storage.PluginManagerUpgradeable
    struct PluginManagerStorage {
        mapping(address plugin => bool) registeredPlugins;
        mapping(address liquidator => bool) registeredLiquidators;
        mapping(address account => mapping(address plugin => bool)) pluginApprovals;
    }

    // keccak256(abi.encode(uint256(keccak256("EquationDAO.storage.PluginManagerUpgradeable")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant PLUGIN_MANAGER_UPGRADEABLE_STORAGE =
        0xf9fe859717463c72f74c7189bf68eb7b4a998dbbeaec3a6b76288d359ba09700;

    function __PluginManager_init() internal onlyInitializing {
        GovernableUpgradeable.__Governable_init();
    }

    /// @inheritdoc IPluginManager
    function registerPlugin(address _plugin) external override onlyGov {
        PluginManagerStorage storage $ = _pluginManagerStorage();
        if ($.registeredPlugins[_plugin]) revert PluginAlreadyRegistered(_plugin);

        $.registeredPlugins[_plugin] = true;

        emit PluginRegistered(_plugin);
    }

    /// @inheritdoc IPluginManager
    function unregisterPlugin(address _plugin) external override onlyGov {
        PluginManagerStorage storage $ = _pluginManagerStorage();
        if (!$.registeredPlugins[_plugin]) revert PluginNotRegistered(_plugin);

        delete $.registeredPlugins[_plugin];
        emit PluginUnregistered(_plugin);
    }

    /// @inheritdoc IPluginManager
    function registeredPlugins(address _plugin) public view override returns (bool) {
        return _pluginManagerStorage().registeredPlugins[_plugin];
    }

    /// @inheritdoc IPluginManager
    function approvePlugin(address _plugin) external override {
        PluginManagerStorage storage $ = _pluginManagerStorage();
        if ($.pluginApprovals[msg.sender][_plugin]) revert PluginAlreadyApproved(msg.sender, _plugin);

        if (!$.registeredPlugins[_plugin]) revert PluginNotRegistered(_plugin);

        $.pluginApprovals[msg.sender][_plugin] = true;
        emit PluginApproved(msg.sender, _plugin);
    }

    /// @inheritdoc IPluginManager
    function revokePlugin(address _plugin) external {
        PluginManagerStorage storage $ = _pluginManagerStorage();
        if (!$.pluginApprovals[msg.sender][_plugin]) revert PluginNotApproved(msg.sender, _plugin);

        delete $.pluginApprovals[msg.sender][_plugin];
        emit PluginRevoked(msg.sender, _plugin);
    }

    /// @inheritdoc IPluginManager
    function isPluginApproved(address _account, address _plugin) public view override returns (bool) {
        return _pluginManagerStorage().pluginApprovals[_account][_plugin];
    }

    /// @inheritdoc IPluginManager
    function registerLiquidator(address _liquidator) external override onlyGov {
        PluginManagerStorage storage $ = _pluginManagerStorage();
        if ($.registeredLiquidators[_liquidator]) revert LiquidatorAlreadyRegistered(_liquidator);

        $.registeredLiquidators[_liquidator] = true;

        emit LiquidatorRegistered(_liquidator);
    }

    /// @inheritdoc IPluginManager
    function unregisterLiquidator(address _liquidator) external override onlyGov {
        PluginManagerStorage storage $ = _pluginManagerStorage();
        if (!$.registeredLiquidators[_liquidator]) revert LiquidatorNotRegistered(_liquidator);

        delete $.registeredLiquidators[_liquidator];
        emit LiquidatorUnregistered(_liquidator);
    }

    /// @inheritdoc IPluginManager
    function isRegisteredLiquidator(address _liquidator) public view override returns (bool) {
        return _pluginManagerStorage().registeredLiquidators[_liquidator];
    }

    function _pluginManagerStorage() private pure returns (PluginManagerStorage storage $) {
        // prettier-ignore
        assembly { $.slot := PLUGIN_MANAGER_UPGRADEABLE_STORAGE }
    }
}
