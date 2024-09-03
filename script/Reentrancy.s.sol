// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/AttestationForwarder.sol";
import "../src/SecurityValidator.sol";
import "../src/TrustedAttesters.sol";
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
        TrustedAttesters trustedAttesters = new TrustedAttesters();
        bytes32 attesterControllerId = bytes32(uint256(0x1));                           // TODO: Pass legitimate value
        address defaultAdmin = 0xC99E8AB127272119a42e30A88087b0DaA4807aDA;              // Corresponds to `VICTIM_PRIVATE_KEY`
        FirewallAccess firewallAccess = new FirewallAccess(defaultAdmin);

        ReentrancyVulnerable reentrancyVulnerable = new ReentrancyVulnerable(
            ISecurityValidator(address(securityValidator)),
            ITrustedAttesters(address(trustedAttesters)),
            attesterControllerId,
            IFirewallAccess(address(firewallAccess))
        );

        // `Checkpoint` set up
        // NOTE: Since the reentrant function takes no arguments,
        // we are relying on setting its threshold based on the
        // decimal value of its function selector. Then we are doubling it,
        // since we want to catch the second instance of it being entered.
        string memory funcSig = "withdraw()";
        uint32 funcSelectorDecimalValue = uint32(bytes4(keccak256(bytes(funcSig))));
        uint192 threshold;

        (bool success, uint256 result) = Math.tryMul(funcSelectorDecimalValue, 2);
        if (success) {
            threshold = uint192(result);
        } else {
            revert UnsuccessfulTryMul();
        }

        Checkpoint memory checkpoint = Checkpoint({
            threshold: threshold,
            refStart: 0, // not used
            refEnd: 0, // not used
            activation: 4,
            trustedOrigin: 0
        });
        reentrancyVulnerable.setCheckpoint(funcSig, checkpoint);

        reentrancyVulnerable.deposit{value: 5 ether}();




        // uint256 attackerPrivateKey = vm.envUint("ATTACKER_PRIVATE_KEY");
        // vm.startBroadcast(attackerPrivateKey);

        // address reentrancyVulnerableAddress = 0xdEADBEeF00000000000000000000000000000000; // TODO: Add address of `ReentrancyVulnerable` contract
        // ReentrancyAttack reentrancyAttack = new ReentrancyAttack(reentrancyVulnerableAddress);




        vm.stopBroadcast();
    }
}
