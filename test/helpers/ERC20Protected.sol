// SPDX-License-Identifier: GNU General Public License Version 3
// See license at: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE-GPLv3.md
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/InternalFirewall.sol";
import "../../src/interfaces/FirewallDependencies.sol";
import "../../src/interfaces/Activation.sol";

contract ERC20Protected is ERC20, InternalFirewall {
    constructor(ISecurityValidator _securityValidator, ITrustedAttesters _trustedAttesters)
        ERC20("Test Token", "TEST")
        InternalFirewall(_securityValidator, ICheckpointHook(address(0)), bytes32(0), IFirewallAccess(address(_trustedAttesters)))
    {
        _updateTrustedAttesters(_trustedAttesters);
        _getFirewallStorage().checkpoints[ERC20.transfer.selector].activation = Activation.AlwaysActive;
        _getFirewallStorage().checkpoints[ERC20.transferFrom.selector].activation = Activation.AlwaysActive;
    }

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        _secureExecution(msg.sender, msg.sig, keccak256(msg.data));
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        _secureExecution(msg.sender, msg.sig, keccak256(msg.data));
        return super.transferFrom(from, to, value);
    }
}
