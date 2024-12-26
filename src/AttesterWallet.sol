// SPDX-License-Identifier: GNU General Public License Version 3
// See license at: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE-GPLv3.md

pragma solidity ^0.8.25;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ISecurityValidator} from "./interfaces/ISecurityValidator.sol";
import {ITrustedAttesters} from "./interfaces/ITrustedAttesters.sol";
import {Attestation} from "./interfaces/Attestation.sol";
import {IAttesterWallet} from "./interfaces/IAttesterWallet.sol";

/**
 * @notice Keeps native currency balances per user transaction origin and spends them
 * when an attester stores an attestation on behalf of such an origin.
 */
contract AttesterWallet is IAttesterWallet, ERC20Upgradeable, AccessControlUpgradeable {
    error ZeroBeneficiary();
    error ZeroChargeAccount();
    error ZeroSecurityValidator();
    error ZeroTrustedAttesters();
    error ZeroAmount();
    error FailedToWithdrawFunds();
    error FailedToFundAttester();
    error UntrustedAttester(address attester);

    /// @notice The security validator singleton which keeps attestations.
    ISecurityValidator public securityValidator;

    /// @notice A registry of trusted attesters which can spend from user balance after
    /// storing an attestation.
    ITrustedAttesters public trustedAttesters;

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes proxy storage with values.
     * @param _securityValidator Security validator singleton contract.
     * @param _trustedAttesters A registry of trusted attesters.
     * @param _defaultAdmin Initial admin of the wallet.
     */
    function initialize(
        ISecurityValidator _securityValidator,
        ITrustedAttesters _trustedAttesters,
        address _defaultAdmin
    ) public initializer {
        __ERC20_init("Forta Attester Gas", "FORTAGAS");
        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        if (address(_securityValidator) == address(0)) revert ZeroSecurityValidator();
        securityValidator = _securityValidator;
        if (address(_trustedAttesters) == address(0)) revert ZeroTrustedAttesters();
        trustedAttesters = _trustedAttesters;
    }

    /**
     * @notice Ensures that the sender is a trusted attester.
     */
    modifier onlyTrustedAttester() {
        if (!trustedAttesters.isTrustedAttester(msg.sender)) revert UntrustedAttester(msg.sender);
        _;
    }

    /**
     * @notice Direct native currency transfers are registered to the balance of the sender.
     */
    receive() external payable {
        if (msg.value == 0) revert ZeroAmount();
        _mint(msg.sender, msg.value);
    }

    /**
     * @notice Sets the security validator address.
     * @param _securityValidator Security validator address
     */
    function setSecurityValidator(ISecurityValidator _securityValidator) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (address(_securityValidator) == address(0)) revert ZeroSecurityValidator();
        securityValidator = _securityValidator;
    }

    /**
     * @notice Adds funds for a given beneficiary.
     * @param beneficiary The attestation and funds beneficiary.
     */
    function deposit(address beneficiary) public payable {
        if (beneficiary == address(0)) revert ZeroBeneficiary();
        if (msg.value == 0) revert ZeroAmount();
        _mint(beneficiary, msg.value);
    }

    /**
     * @notice Withdraws balance back to sender.
     * @param amount Withdrawn amount.
     * @param beneficiary Beneficiary of the withdrawal.
     */
    function withdraw(uint256 amount, address beneficiary) public {
        if (beneficiary == address(0)) revert ZeroBeneficiary();
        if (amount == 0) revert ZeroAmount();
        _burn(msg.sender, amount);
        (bool success,) = beneficiary.call{value: amount}(""); // send funds to msg.sender
        if (!success) revert FailedToWithdrawFunds();
    }

    /**
     * @notice Withdraws all balance back to sender.
     * @param beneficiary Beneficiary of the withdrawal.
     */
    function withdrawAll(address beneficiary) public {
        if (beneficiary == address(0)) revert ZeroBeneficiary();
        uint256 currBalance = balanceOf(msg.sender);
        if (currBalance == 0) revert ZeroAmount();
        withdraw(currBalance, beneficiary);
    }

    /**
     * @notice Stores an attestation on behalf of a beneficiary and charges the beneficiary
     * after the operation.
     * @param attestation The set of fields that correspond to and enable the execution of call(s)
     * @param attestationSignature Signature of EIP-712 message
     * @param beneficiary The tx.origin which will benefit from this attestation
     * @param chargeAccount The account charged for this attestation transaction.
     * @param chargeAmount The amount which the charged account is charged for this attestation transaction.
     */
    function storeAttestationForOrigin(
        Attestation calldata attestation,
        bytes calldata attestationSignature,
        address beneficiary,
        address chargeAccount,
        uint256 chargeAmount
    ) public onlyTrustedAttester {
        if (beneficiary == address(0)) revert ZeroBeneficiary();
        if (chargeAccount == address(0)) revert ZeroChargeAccount();
        if (chargeAmount == 0) revert ZeroAmount();
        securityValidator.storeAttestationForOrigin(attestation, attestationSignature, beneficiary);
        /// Burn from user balance and send user ETH to the attester EOA.
        _burn(chargeAccount, chargeAmount);
        (bool success,) = msg.sender.call{value: chargeAmount}("");
        if (!success) revert FailedToFundAttester();
    }
}
