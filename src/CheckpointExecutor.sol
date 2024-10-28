// SPDX-License-Identifier: GNU General Public License Version 3
// See license at: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE-GPLv3.md

pragma solidity ^0.8.25;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import "./interfaces/IExternalFirewall.sol";

/**
 * @notice A helper contract to call an external firewall.
 */
abstract contract CheckpointExecutor {
    using StorageSlot for bytes32;

    struct CheckpointExecutorStorage {
        IExternalFirewall externalFirewall;
    }

    /// @custom:storage-location erc7201:forta.CheckpointExecutor.storage
    bytes32 private constant STORAGE_SLOT = 0x056e02eadf378bb204991810c69f5fd30d0c5daa999b3432711954755cff9a00;

    /**
     * @notice Executes a checkpoint by calling a known external firewall contract.
     * @param selector Selector of the function which the checkpoint is configured and executed for
     * @param ref The reference number to compare with the threshold
     */
    function _executeCheckpoint(bytes4 selector, uint256 ref) internal virtual {
        _getCheckpointExecutorStorage().externalFirewall.executeCheckpoint(msg.sender, selector, ref);
    }

    /**
     * @notice Executes a checkpoint by calling a known external firewall contract.
     * @param selector Selector of the function which the checkpoint is configured and executed for
     * @param input The input value to use in checkpoint hash computation
     */
    function _executeCheckpoint(bytes4 selector, bytes32 input) internal virtual {
        _getCheckpointExecutorStorage().externalFirewall.executeCheckpoint(msg.sender, selector, input);
    }

    /**
     * @notice Sets the external firewall in the namespaced storage.
     * @param externalFirewall New external firewall
     */
    function _setExternalFirewall(IExternalFirewall externalFirewall) internal virtual {
        _getCheckpointExecutorStorage().externalFirewall = externalFirewall;
    }

    /**
     * @notice Helps write an attestation through the external firewall and call any function
     * of this contract.
     * @param attestation The set of fields that correspond to and enable the execution of call(s)
     * @param attestationSignature Signature of EIP-712 message
     * @param data Call data which contains the function selector and the encoded arguments
     */
    function attestedCall(Attestation calldata attestation, bytes calldata attestationSignature, bytes calldata data)
        public
        returns (bytes memory)
    {
        _getCheckpointExecutorStorage().externalFirewall.saveAttestation(attestation, attestationSignature);
        return Address.functionDelegateCall(address(this), data);
    }

    function _getCheckpointExecutorStorage() internal pure virtual returns (CheckpointExecutorStorage storage $) {
        assembly {
            $.slot := STORAGE_SLOT
        }
    }
}
