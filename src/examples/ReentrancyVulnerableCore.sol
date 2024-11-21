// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract ReentrancyVulnerableCore {
    mapping(address => uint) public balances;

    function deposit() public payable {
        require(msg.value > 0, "Deposit value must be greater than 0");
        balances[msg.sender] += msg.value;
    }

    function _withdraw() internal {
        uint balance = balances[msg.sender];
        require(balance > 0, "Insufficient balance");

        (bool sent, ) = msg.sender.call{value: balance}("");
        require(sent, "Failed to send Ether");

        balances[msg.sender] = 0;
    }
}