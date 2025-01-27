// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {SecurityValidator} from "../src/SecurityValidator.sol";
import {ITrustedAttesters} from "../src/interfaces/ITrustedAttesters.sol";
import {ProtectedContract} from "../test/helpers/ProtectedContract.sol";

contract TestDeployer is Script {
    function run() public {
        string memory deployerPrivateKeyStr = vm.envString("DEPLOY_KEY");
        uint256 deployer = vm.parseUint(deployerPrivateKeyStr);

        vm.startBroadcast(deployer);

        SecurityValidator validator = new SecurityValidator(ITrustedAttesters(address(0)));
        ProtectedContract protectedContract = new ProtectedContract(validator);

        console.log("validator contract:", address(validator));
        console.log("protected contract:", address(protectedContract));

        vm.stopBroadcast();
    }
}
