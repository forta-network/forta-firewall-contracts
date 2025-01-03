// SPDX-License-Identifier: GNU General Public License Version 3
// See license at: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE-GPLv3.md

pragma solidity ^0.8.25;

import "./interfaces/IFirewallAccess.sol";
import "./interfaces/ITrustedAttesters.sol";

/**
 * @notice Simplifies interactions with a firewall access contract.
 */
abstract contract FirewallPermissions {
    error CallerNotFirewallAdmin(address caller);
    error CallerNotCheckpointManager(address caller);
    error CallerNotLogicUpgrader(address caller);
    error CallerNotCheckpointExecutor(address caller);
    error ZeroFirewallAccess();

    struct FirewallPermissionsStorage {
        IFirewallAccess firewallAccess;
        ITrustedAttesters trustedAttesters;
    }

    /// @custom:storage-location erc7201:forta.FirewallPermissions.storage
    bytes32 private constant STORAGE_SLOT = 0x5a36dfc2750cc10abe5f95f24b6fce874396e21527ff7f50fb33b5ccc8b7d500;

    modifier onlyFirewallAdmin() {
        if (!_getFirewallPermissionsStorage().firewallAccess.isFirewallAdmin(msg.sender)) {
            revert CallerNotFirewallAdmin(msg.sender);
        }
        _;
    }

    modifier onlyCheckpointManager() {
        if (!_getFirewallPermissionsStorage().firewallAccess.isCheckpointManager(msg.sender)) {
            revert CallerNotCheckpointManager(msg.sender);
        }
        _;
    }

    modifier onlyLogicUpgrader() {
        if (!_getFirewallPermissionsStorage().firewallAccess.isLogicUpgrader(msg.sender)) {
            revert CallerNotLogicUpgrader(msg.sender);
        }
        _;
    }

    modifier onlyCheckpointExecutor() {
        if (!_getFirewallPermissionsStorage().firewallAccess.isCheckpointExecutor(msg.sender)) {
            revert CallerNotCheckpointExecutor(msg.sender);
        }
        _;
    }

    function _updateFirewallAccess(IFirewallAccess firewallAccess) internal {
        if (address(firewallAccess) == address(0)) revert ZeroFirewallAccess();
        _getFirewallPermissionsStorage().firewallAccess = firewallAccess;
    }

    function _getFirewallAccess() internal view returns (IFirewallAccess) {
        return _getFirewallPermissionsStorage().firewallAccess;
    }

    function _updateTrustedAttesters(ITrustedAttesters trustedAttesters) internal {
        _getFirewallPermissionsStorage().trustedAttesters = trustedAttesters;
    }

    function _getTrustedAttesters() internal view returns (ITrustedAttesters) {
        return _getFirewallPermissionsStorage().trustedAttesters;
    }

    function _getFirewallPermissionsStorage() private pure returns (FirewallPermissionsStorage storage $) {
        assembly {
            $.slot := STORAGE_SLOT
        }
    }

    function _isTrustedAttester(address attester) internal view returns (bool) {
        FirewallPermissionsStorage storage $ = _getFirewallPermissionsStorage();
        if (address($.trustedAttesters) != address(0)) {
            return $.trustedAttesters.isTrustedAttester(attester);
        }
        return $.firewallAccess.isTrustedAttester(attester);
    }
}
