// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {SecurityValidator} from "../src/SecurityValidator.sol";
import {ITrustedAttesters} from "../src/interfaces/ITrustedAttesters.sol";
import "../src/interfaces/FirewallDependencies.sol";
import {TrustedAttesters, ATTESTER_MANAGER_ROLE, TRUSTED_ATTESTER_ROLE} from "../src/TrustedAttesters.sol";
import {AttesterWallet} from "../src/AttesterWallet.sol";
import {ERC20Protected} from "../test/helpers/ERC20Protected.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ERC20ProtectedDeployer is Script {
    function run() public {
        string memory deployerPrivateKeyStr = vm.envString("DEPLOY_KEY");
        uint256 deployer = vm.parseUint(deployerPrivateKeyStr);

        vm.startBroadcast(deployer);

        ERC20Protected protectedToken =
            new ERC20Protected(ISecurityValidator(0xff6610cD321cDaE3248aAE0e731BfD5CF1d081C0), ITrustedAttesters(address(0x35b226B1046dC6614471fcD4E1117C9279720529)));

        console.log("# protected token contract:", address(protectedToken));

        vm.stopBroadcast();
    }
}
