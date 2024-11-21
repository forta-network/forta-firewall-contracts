// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/AttestationForwarder.sol";
import "../src/SecurityValidator.sol";
import "../src/FirewallAccess.sol";
import "../src/examples/ReentrancyVulnerable.sol";
import "../src/Firewall.sol";
import {ReentrancyAttack} from "../src/examples/ReentrancyAttack.sol";

error UnsuccessfulTryMul();

contract Reentrancy is Script {
    function run() external {
        uint256 victimPrivateKey = vm.envUint("VICTIM_PRIVATE_KEY");
        vm.startBroadcast(victimPrivateKey);

        // Set up `InternalFirewall` constructor args
        AttestationForwarder _trustedForwarder = new AttestationForwarder();
        SecurityValidator securityValidator = new SecurityValidator(address(_trustedForwarder));
        // Id of Attester Controller deployed for reentrancy demo
        bytes32 attesterControllerId = bytes32(uint256(1));
        // Corresponds to `VICTIM_PRIVATE_KEY`
        address defaultAdmin = 0xC99E8AB127272119a42e30A88087b0DaA4807aDA;
        FirewallAccess firewallAccess = new FirewallAccess(defaultAdmin);

        // Set up access controls to properly execute benign and exploit txns
        firewallAccess.grantRole(FIREWALL_ADMIN_ROLE, defaultAdmin);
        firewallAccess.grantRole(PROTOCOL_ADMIN_ROLE, defaultAdmin);
        firewallAccess.grantRole(ATTESTER_MANAGER_ROLE, defaultAdmin);
        address trustedAttester = 0xae9554eC2f8cc606C6543721d07Fa4aaDC555272;
        firewallAccess.grantRole(TRUSTED_ATTESTER_ROLE, trustedAttester);

        ReentrancyVulnerable reentrancyVulnerable = new ReentrancyVulnerable(
            ISecurityValidator(address(securityValidator)),
            attesterControllerId,
            IFirewallAccess(address(firewallAccess))
        );

        // `Checkpoint` set up
        string memory funcSig = "withdraw()";
        bytes4 funcSelector = bytes4(keccak256(bytes(funcSig)));
        uint192 threshold = 2 ether;

        Checkpoint memory checkpoint = Checkpoint({
            threshold: threshold,
            refStart: 0,    // not used
            refEnd: 0,      // not used
            activation: Activation.AccumulatedThreshold,
            trustedOrigin: false
        });
        reentrancyVulnerable.setCheckpoint(funcSelector, checkpoint);




        // uint256 attackerPrivateKey = vm.envUint("ATTACKER_PRIVATE_KEY");
        // vm.startBroadcast(attackerPrivateKey);

        // // Should be set to address of `ReentrancyVulnerable` contract deployed at L33-37
        // address reentrancyVulnerableAddress = 0xAEbe8393e30bb2A6538399ED0Da9926a81202462;
        // ReentrancyAttack reentrancyAttack = new ReentrancyAttack(reentrancyVulnerableAddress);




        vm.stopBroadcast();
    }
}
