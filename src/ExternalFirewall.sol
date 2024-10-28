// SPDX-License-Identifier: GNU General Public License Version 3
// See license at: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE-GPLv3.md

pragma solidity ^0.8.25;

import {Firewall} from "./Firewall.sol";
import "./interfaces/IExternalFirewall.sol";
import "./interfaces/ISecurityValidator.sol";
import "./interfaces/ICheckpointHook.sol";
import "./interfaces/IFirewallAccess.sol";

/**
 * @notice This contract provides firewall functionality externally. The integrator contract
 * should inherit the CheckpointExecutor contract and use the _executeCheckpoint()
 * function to call this contract. The checkpoints must be adjusted by calling the
 * setCheckpoint() function.
 */
contract ExternalFirewall is IExternalFirewall, Firewall {
    constructor(
        ISecurityValidator _validator,
        ICheckpointHook _checkpointHook,
        bytes32 _attesterControllerId,
        IFirewallAccess _firewallAccess
    ) {
        _updateFirewallConfig(_validator, _checkpointHook, _attesterControllerId, _firewallAccess);
    }

    /**
     * @notice Allows executing checkpoints externally from an integrator contract. The selector
     * is checked against the checkpoints configured on this contract.
     * @param selector Selector of the function which the checkpoint is configured and executed for
     * @param ref The reference number to compare with the threshold
     */
    function executeCheckpoint(address caller, bytes4 selector, uint256 ref) public onlyCheckpointExecutor {
        _secureExecution(caller, selector, ref);
    }

    /**
     * @notice Allows executing checkpoints externally from an integrator contract. The selector
     * is checked against the checkpoints configured on this contract.
     * @param selector Selector of the function which the checkpoint is configured and executed for
     * @param input The input value to use in checkpoint hash computation
     */
    function executeCheckpoint(address caller, bytes4 selector, bytes32 input) public onlyCheckpointExecutor {
        _secureExecution(caller, selector, input);
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
        _getFirewallStorage().validator.saveAttestation(attestation, attestationSignature);
    }
}
