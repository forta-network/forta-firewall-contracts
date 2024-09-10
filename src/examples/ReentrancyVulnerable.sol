// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ReentrancyVulnerableCore.sol";
import "../InternalFirewall.sol";

contract ReentrancyVulnerable is  ReentrancyVulnerableCore, InternalFirewall {

    constructor(
        ISecurityValidator _validator,
        bytes32 _attesterControllerId,
        IFirewallAccess _firewallAccess
    ) InternalFirewall(_validator, _attesterControllerId, _firewallAccess) {}

    function withdraw() public {
        _secureExecution(balances[msg.sender]);
        _withdraw();
    }
}