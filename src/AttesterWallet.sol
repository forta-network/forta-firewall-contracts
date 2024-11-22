// SPDX-License-Identifier: GNU General Public License Version 3
// See license at: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE-GPLv3.md

pragma solidity ^0.8.25;

import {ERC2771Forwarder} from "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ISecurityValidator} from "./interfaces/ISecurityValidator.sol";
import {ITrustedAttesters} from "./interfaces/ITrustedAttesters.sol";
import {Attestation} from "./interfaces/Attestation.sol";
import {IAttesterWallet} from "./interfaces/IAttesterWallet.sol";

/**
 * @notice Keeps native currency balances per user transaction origin and spends them
 * when an attester stores an attestation on behalf of such an origin.
 */
contract AttesterWallet is IAttesterWallet, AccessControl {
    using Math for uint256;

    error ZeroBeneficiary();
    error InsufficientFunds(address beneficiary);
    error FailedToWithdrawFunds();
    error FailedToFundAttester();

    /// @notice The security validator singleton which keeps attestations.
    ISecurityValidator public securityValidator;

    /// @notice A registry of trusted attesters which can spend from user balance after
    /// storing an attestation.
    ITrustedAttesters public trustedAttesters;

    /// @notice A gas overhead amount which is added to the charged amount.
    uint256 extraGasOverhead = 35000;

    /// @notice All sender balances calculated and stored, after receiving and sending.
    mapping(address => uint256) balances;

    constructor(ITrustedAttesters _trustedAttesters, address _defaultAdmin) {
        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        trustedAttesters = _trustedAttesters;
    }

    /**
     * @notice Ensures that the sender is a trusted attester.
     */
    modifier onlyTrustedAttester() {
        require(trustedAttesters.isTrustedAttester(msg.sender), "sender is not a trusted attester");
        _;
    }

    /**
     * @notice Charges given beneficiary by using available balance. It first gets the initial gas
     * available, then proceed with the modified function logic and finally deducts the spent amount.
     * A predicted extra gas overhead is added for avoiding attester losses.
     */
    modifier chargeForAttestation(address beneficiary) {
        uint256 initialGas = gasleft();
        _;
        uint256 spentAmount = initialGas - gasleft() + extraGasOverhead;
        (bool success, uint256 finalAmount) = balances[beneficiary].trySub(spentAmount);
        if (!success) revert InsufficientFunds(beneficiary);
        (success,) = msg.sender.call{value: spentAmount}(""); // send funds to the attester EOA
        if (!success) revert FailedToFundAttester();
        balances[beneficiary] = finalAmount;
    }

    /**
     * @notice Direct native currency transfers are registered to the balance of the sender.
     */
    receive() external payable {
        balances[msg.sender] += msg.value;
    }

    /**
     * @notice Sets the security validator address.
     * @param _securityValidator Security validator address
     */
    function setSecurityValidator(ISecurityValidator _securityValidator) public onlyRole(DEFAULT_ADMIN_ROLE) {
        securityValidator = _securityValidator;
    }

    /**
     * @notice Sets the extra gas overhead.
     * @param _extraGasOverhead Predicted extra gas overhead amount
     */
    function setExtraGasOverhead(uint256 _extraGasOverhead) public onlyRole(DEFAULT_ADMIN_ROLE) {
        extraGasOverhead = _extraGasOverhead;
    }

    /**
     * @notice Adds funds for a given beneficiary.
     * @param beneficiary The attestation and funds beneficiary.
     */
    function deposit(address beneficiary) public payable {
        if (beneficiary == address(0)) revert ZeroBeneficiary();
        balances[beneficiary] += msg.value;
    }

    /**
     * @notice Withdraws balance back to sender.
     */
    function withdraw(uint256 amount) public {
        if (balances[msg.sender] < amount) revert InsufficientFunds(msg.sender);
        (bool success,) = msg.sender.call{value: amount}(""); // send funds to msg.sender
        if (!success) revert FailedToWithdrawFunds();
    }

    /**
     * @notice Withdraws all balance back to sender.
     */
    function withdrawAll() public {
        withdraw(balances[msg.sender]);
    }

    /**
     * @notice Returns the balance of given beneficiary.
     * @param beneficiary The attestation beneficiary.
     */
    function balanceOf(address beneficiary) public view returns (uint256) {
        return balances[beneficiary];
    }

    /**
     * @notice Stores an attestation on behalf of a beneficiary and charges the beneficiary
     * after the operation.
     * @param attestation The set of fields that correspond to and enable the execution of call(s)
     * @param attestationSignature Signature of EIP-712 message
     * @param beneficiary The tx.origin which will benefit from this attestation
     */
    function storeAttestationForOrigin(
        Attestation calldata attestation,
        bytes calldata attestationSignature,
        address beneficiary
    ) public onlyTrustedAttester chargeForAttestation(beneficiary) {
        securityValidator.storeAttestationForOrigin(attestation, attestationSignature, beneficiary);
    }
}
