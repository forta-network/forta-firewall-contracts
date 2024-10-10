// SPDX-License-Identifier: UNLICENSED
// See Forta Network License: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE.md

pragma solidity ^0.8.25;

import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {IExternalFirewall} from "./ExternalFirewall.sol";

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
        CheckpointExecutorStorage storage $;
        assembly {
            $.slot := STORAGE_SLOT
        }
        IExternalFirewall($.externalFirewall).executeCheckpoint(msg.sender, selector, ref);
    }

    /**
     * @notice Sets the external firewall in the namespaced storage.
     * @param externalFirewall New external firewall
     */
    function _setExternalFirewall(IExternalFirewall externalFirewall) internal virtual {
        CheckpointExecutorStorage storage $;
        assembly {
            $.slot := STORAGE_SLOT
        }
        $.externalFirewall = externalFirewall;
    }
}
