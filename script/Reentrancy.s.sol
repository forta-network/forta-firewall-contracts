// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/SecurityValidator.sol";
import "../src/TrustedAttesters.sol";
import "../src/FirewallAccess.sol";
import "../src/examples/ReentrancyVulnerable.sol";
import "../src/examples/ReentrancyAttack.sol";

contract Reentrancy is Script {
    function run() external {
        uint256 victimPrivateKey = vm.envUint("VICTIM_PRIVATE_KEY");
        vm.startBroadcast(victimPrivateKey);

        // Set up `InternalFirewall` constructor args
        address _trustedForwarder = address(0);                                         // Fine for demo purposes?
        SecurityValidator securityValidator = new SecurityValidator(_trustedForwarder);
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

        reentrancyVulnerable.deposit{value: 5 ether}();




        // uint256 attackerPrivateKey = vm.envUint("ATTACKER_PRIVATE_KEY");
        // vm.startBroadcast(attackerPrivateKey);

        // address reentrancyVulnerableAddress = 
        // ReentrancyAttack reentrancyAttack = new ReentrancyAttack(reentrancyVulnerableAddress);

        // // reentrancyAttack.attack{value: 1 ether}();
        // // reentrancyAttack.withdrawFunds();





        vm.stopBroadcast();
    }
}