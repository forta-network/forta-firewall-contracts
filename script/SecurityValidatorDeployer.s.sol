// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {SecurityValidator} from "../src/SecurityValidator.sol";
import {TrustedAttesters} from "../src/TrustedAttesters.sol";

contract SecurityValidatorDeployerScript is Script {
    function run() public {
        string memory deployerPrivateKeyStr = vm.envString("DEPLOY_KEY");
        uint256 deployer = vm.parseUint(deployerPrivateKeyStr);

        vm.startBroadcast(deployer);

        TrustedAttesters trustedAttesters = new TrustedAttesters(vm.addr(deployer));
        SecurityValidator validator = new SecurityValidator(trustedAttesters);

        console.log("trusted attesters contract:", address(trustedAttesters));
        console.log("validator contract:", address(validator));

        vm.stopBroadcast();
    }
}
