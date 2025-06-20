// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {ProxyFirewall} from "../src/ProxyFirewall.sol";
import {FirewallAccess} from "../src/FirewallAccess.sol";

contract ProxyFirewallDeployer is Script {
    function run() public {
        string memory deployerPrivateKeyStr = vm.envString("DEPLOY_KEY");
        uint256 deployer = vm.parseUint(deployerPrivateKeyStr);

        vm.startBroadcast(deployer);

        FirewallAccess firewallAccess = new FirewallAccess(vm.addr(deployer));
        ProxyFirewall proxyFirewall = new ProxyFirewall();

        console.log("firewall access:", address(firewallAccess));
        console.log("proxy firewall:", address(proxyFirewall));

        vm.stopBroadcast();
    }
}
