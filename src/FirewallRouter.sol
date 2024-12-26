// SPDX-License-Identifier: GNU General Public License Version 3
// See license at: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE-GPLv3.md

pragma solidity ^0.8.25;

import "./interfaces/IExternalFirewall.sol";
import "./interfaces/ICheckpointHook.sol";
import "./interfaces/IFirewallAccess.sol";
import "./FirewallPermissions.sol";

/**
 * @notice This contract provides external firewall upgradeability.
 */
contract FirewallRouter is IExternalFirewall, FirewallPermissions {
    /// @notice External firewall address.
    IExternalFirewall public firewall;

    constructor(IExternalFirewall _firewall, IFirewallAccess _firewallAccess) {
        firewall = _firewall;
        _updateFirewallAccess(_firewallAccess);
    }

    /**
     * @notice Allows executing checkpoints externally from an integrator contract. The selector
     * is checked against the checkpoints configured on this contract.
     * @param caller The caller observed by the checkpoint executor (protected) contract
     * @param selector Selector of the function which the checkpoint is configured and executed for
     * @param ref The reference number to compare with the threshold
     */
    function executeCheckpoint(address caller, bytes4 selector, uint256 ref) public onlyCheckpointExecutor {
        firewall.executeCheckpoint(caller, selector, ref);
    }

    /**
     * @notice Allows executing checkpoints externally from an integrator contract. The selector
     * is checked against the checkpoints configured on this contract.
     * @param caller The caller observed by the checkpoint executor (protected) contract
     * @param selector Selector of the function which the checkpoint is configured and executed for
     * @param input The input value to use in checkpoint hash computation
     */
    function executeCheckpoint(address caller, bytes4 selector, bytes32 input) public onlyCheckpointExecutor {
        firewall.executeCheckpoint(caller, selector, input);
    }

    /**
     * @notice Accepts and stores an attestation to the transient storage introduced
     * with EIP-1153. Multiple contracts that operate in the same transaction can call
     * a singleton of this contract. The stored values are later used during checkpoint
     * execution.
     * @param attestation The set of fields that correspond to and enable the execution of call(s)
     * @param attestationSignature Signature of EIP-712 message
     */
    function saveAttestation(Attestation calldata attestation, bytes calldata attestationSignature) public {
        firewall.saveAttestation(attestation, attestationSignature);
    }

    /**
     * @notice Updates the external firewall address.
     * @param newFirewall New external firewall address.
     */
    function updateFirewall(IExternalFirewall newFirewall) public onlyFirewallAdmin {
        firewall = newFirewall;
    }

    /**
     * @notice Updates the firewall access contract address.
     * @param newFirewallAccess New firewall access contract address.
     */
    function updateFirewallAccess(IFirewallAccess newFirewallAccess) public onlyFirewallAdmin {
        _updateFirewallAccess(newFirewallAccess);
    }
}
