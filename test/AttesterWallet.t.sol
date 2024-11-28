// SPDX-License-Identifier: GNU General Public License Version 3
// See license at: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE-GPLv3.md
pragma solidity ^0.8.25;

import {Test, console, Vm} from "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./helpers/DummyVault.sol";
import {SecurityValidator, BYPASS_FLAG} from "../src/SecurityValidator.sol";
import "../src/TrustedAttesters.sol";
import "../src/interfaces/ITrustedAttesters.sol";
import "../src/AttesterWallet.sol";

contract AttesterWalletTest is Test {
    uint256 attesterPrivateKey;
    address attester;
    uint256 userPrivateKey;
    address user;
    uint256 otherUserPrivateKey;
    address otherUser;

    SecurityValidator validator;
    TrustedAttesters trustedAttesters;
    AttesterWallet attesterWallet;

    Attestation attestation;
    bytes attestationSignature;

    bytes32 executionHash1 = bytes32(uint256(0x777));
    bytes32 executionHash2 = bytes32(uint256(0x888));

    function setUp() public {
        attesterPrivateKey = vm.parseUint("0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");
        attester = vm.addr(attesterPrivateKey);
        userPrivateKey = uint256(keccak256("user"));
        user = vm.addr(userPrivateKey);
        otherUserPrivateKey = uint256(keccak256("otherUser"));
        otherUser = vm.addr(otherUserPrivateKey);

        trustedAttesters = new TrustedAttesters(address(this));
        trustedAttesters.grantRole(ATTESTER_MANAGER_ROLE, address(this));
        trustedAttesters.grantRole(TRUSTED_ATTESTER_ROLE, address(attester));

        validator = new SecurityValidator(address(0), trustedAttesters);
        attesterWallet = new AttesterWallet(trustedAttesters, address(this));

        trustedAttesters.grantRole(TRUSTED_ATTESTER_ROLE, address(attesterWallet));
        attesterWallet.setSecurityValidator(validator);

        /// very large - in seconds
        attestation.deadline = 1000000000;
        attestation.executionHashes = new bytes32[](2);
        attestation.executionHashes[0] = executionHash1;
        attestation.executionHashes[1] = executionHash2;

        bytes32 hashOfAttestation = validator.hashAttestation(attestation);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attesterPrivateKey, hashOfAttestation);
        attestationSignature = abi.encodePacked(r, s, v);
    }

    function testAttesterWalletStoreAttestation() public {
        deal(attester, 1 ether);
        deal(user, 1 ether);

        vm.prank(user);
        attesterWallet.deposit{value: 0.5 ether}(user);

        vm.prank(attester);
        vm.startSnapshotGas("store-attestation");
        attesterWallet.storeAttestationForOrigin(attestation, attestationSignature, user);
        uint256 gasUsed = vm.stopSnapshotGas();

        console.log("gas used for attestation tx:", gasUsed);
        console.log("attester compensation:", (attester.balance - 1 ether));
    }

    function testAttesterWalletDepositWithdraw() public {
        deal(user, 10 ether);

        vm.prank(user);
        attesterWallet.deposit{value: 0.5 ether}(user);
        vm.prank(user);
        (bool success,) = address(attesterWallet).call{value: 0.4 ether}("");
        assertTrue(success);

        assertEq(0.9 ether, attesterWallet.balanceOf(user));

        vm.prank(user);
        attesterWallet.withdraw(0.9 ether, otherUser);

        assertEq(0.9 ether, otherUser.balance);

        vm.prank(user);
        attesterWallet.deposit{value: 0.5 ether}(user);
        vm.prank(user);
        attesterWallet.withdrawAll(otherUser);

        assertEq(1.4 ether, otherUser.balance);
    }
}
