// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {CheckpointExecutor} from "../CheckpointExecutor.sol";
import {ExternalFirewall} from "../ExternalFirewall.sol";
import {ISecurityValidator} from "../interfaces/ISecurityValidator.sol";
import {FirewallAccess} from "../FirewallAccess.sol";
import {IExternalFirewall} from "../interfaces/IExternalFirewall.sol";
import {ICheckpointHook} from "../interfaces/ICheckpointHook.sol";

contract ProtectedContract is CheckpointExecutor {
    constructor(IExternalFirewall externalFirewall) {
        _setExternalFirewall(externalFirewall);
    }

    modifier safeExecution() {
        _executeCheckpoint(msg.sig, keccak256(msg.data));
        _;
    }

    function foo(uint256 num) public {}
}

contract Deployer {
    event DeployedFirewall(ExternalFirewall firewall);
    event DeployedProtectedContract(ProtectedContract protectedContract);

    constructor(ISecurityValidator validator, address firewallAdmin, bytes32 attesterControllerId) {
        FirewallAccess firewallAccess = new FirewallAccess(firewallAdmin);

        ExternalFirewall externalFirewall =
            new ExternalFirewall(validator, ICheckpointHook(address(0)), attesterControllerId, firewallAccess);
        emit DeployedFirewall(externalFirewall);

        ProtectedContract protectedContract = new ProtectedContract(externalFirewall);
        emit DeployedProtectedContract(protectedContract);

        /// Next steps:
        /// - Grant ProtectedContact the CHECKPOINT_EXECUTOR_ROLE.
        /// - Set a checkpoint for "foo" func in the firewall by using the firewall admin account.
    }
}
