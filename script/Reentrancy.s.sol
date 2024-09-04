// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/AttestationForwarder.sol";
import "../src/SecurityValidator.sol";
import "../src/FirewallAccess.sol";
import "../src/examples/ReentrancyVulnerable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
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
        bytes32 attesterControllerId = bytes32(uint256(1));                             // Id of Attester Controller deployed for reentrancy demo
        address defaultAdmin = 0xC99E8AB127272119a42e30A88087b0DaA4807aDA;              // Corresponds to `VICTIM_PRIVATE_KEY`
        FirewallAccess firewallAccess = new FirewallAccess(defaultAdmin);

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

        // reentrancyVulnerable.deposit{value: 5 ether}();




        // uint256 attackerPrivateKey = vm.envUint("ATTACKER_PRIVATE_KEY");
        // vm.startBroadcast(attackerPrivateKey);

        // address reentrancyVulnerableAddress = 0xdEADBEeF00000000000000000000000000000000; // TODO: Add address of `ReentrancyVulnerable` contract
        // ReentrancyAttack reentrancyAttack = new ReentrancyAttack(reentrancyVulnerableAddress);




        vm.stopBroadcast();
    }
}
