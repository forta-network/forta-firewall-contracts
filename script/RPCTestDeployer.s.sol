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

contract RPCTestDeployer is Script {
    function run() public {
        string memory deployerPrivateKeyStr = vm.envString("DEPLOY_KEY");
        uint256 deployer = vm.parseUint(deployerPrivateKeyStr);
        address deployerAddr = vm.addr(deployer);

        address trustedAttester = vm.envAddress("RPC_TEST_TRUSTED_ATTESTER");

        vm.startBroadcast(deployer);

        TrustedAttesters trustedAttesters = new TrustedAttesters(deployerAddr);
        trustedAttesters.grantRole(ATTESTER_MANAGER_ROLE, deployerAddr);
        trustedAttesters.grantRole(TRUSTED_ATTESTER_ROLE, trustedAttester);
        SecurityValidator validator = new SecurityValidator(ITrustedAttesters(address(trustedAttesters)));
        AttesterWallet attesterWallet = new AttesterWallet();
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,address)",
            ISecurityValidator(address(validator)),
            ITrustedAttesters(address(trustedAttesters)),
            deployerAddr
        );
        console.log("# attester wallet proxy init data:");
        console.logBytes(initData);
        ERC1967Proxy attesterWalletProxy = new ERC1967Proxy(address(attesterWallet), initData);
        ERC20Protected protectedToken =
            new ERC20Protected(ISecurityValidator(address(validator)), ITrustedAttesters(address(trustedAttesters)));

        console.log("# trusted attesters contract:", address(trustedAttesters));
        console.log("# validator contract:", address(validator));
        console.log("# attester wallet contract:", address(attesterWalletProxy));
        console.log("# protected token contract:", address(protectedToken));

        vm.stopBroadcast();
    }
}
