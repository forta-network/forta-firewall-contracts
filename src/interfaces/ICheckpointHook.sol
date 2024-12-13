// SPDX-License-Identifier: GNU General Public License Version 3
// See license at: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE-GPLv3.md

pragma solidity ^0.8.25;

/**
 * @notice External checkpoint activation values to enforce on the firewall when the firewall
 * calls the configured checkpoint hook contract.
 */
enum HookResult {
    Inconclusive,
    ForceActivation,
    ForceDeactivation
}

/**
 * @notice An interface for a custom contract implement and point the firewall to. This allows
 * building custom external logic that enforces what the firewall should think about an executing
 * checkpoint which will require an attestation. For example, by using this, a checkpoint can be
 * force activated or deactivated based on the caller. Returning HookResult.Inconclusive lets
 * the firewall fall back to its own configuration and logic to execute a checkpoint.
 */
interface ICheckpointHook {
    /**
     * @notice Called by a firewall when the address is configured in settings and the checkpoint
     * is based on a hash of the call data.
     * @param caller The caller observed and reported by the firewall.
     * @param selector The function selector which the checkpoint is configured for.
     */
    function handleCheckpoint(address caller, bytes4 selector) external view returns (HookResult);
    /**
     * @notice Called by a firewall when the address is configured in settings and the checkpoint
     * is based on a reference number selected from the call data. The difference from handleCheckpoint()
     * is the ability to reason about
     * @param caller The caller observed and reported by the firewall.
     * @param selector The function selector which the checkpoint is configured for.
     * @param ref The reference value which can normally be compared to a threshold value. The firewall
     * implementations use this value when deciding whether a checkpoint should activate and this hook
     * function can help add custom reasoning.
     */
    function handleCheckpointWithRef(address caller, bytes4 selector, uint256 ref) external view returns (HookResult);
}
