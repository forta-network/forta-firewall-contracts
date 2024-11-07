// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {AttestationForwarder} from "../src/AttestationForwarder.sol";
import {SecurityValidator} from "../src/SecurityValidator.sol";

contract SecurityValidatorDeployerScript is Script {
    function run() public {
        string memory deployerPrivateKeyStr = vm.envString("DEPLOY_KEY");
        uint256 deployer = vm.parseUint(deployerPrivateKeyStr);

        vm.startBroadcast(deployer);

        AttestationForwarder forwarder = new AttestationForwarder();
        SecurityValidator validator = new SecurityValidator(address(0));

        console.log("forwarder contract:", address(forwarder));
        console.log("validator contract:", address(validator));

        vm.stopBroadcast();
    }
}
