require('dotenv/config');
const { ethers } = require('ethers');

const attesterUrl = process.env.ATTESTER_URL;


const jsonRpcUrl = process.env.ETH_SEPOLIA_RPC_URL;
const provider = new ethers.JsonRpcProvider(jsonRpcUrl);
// 1 ETH in hexadecimal 
// with leading zero removed
const oneEthInHex = "0xde0b6b3a7640000";


const reentrancyVictim = new ethers.Wallet(process.env.VICTIM_PRIVATE_KEY, provider);
const reentrancyVictimAddress = reentrancyVictim.address;
const reentrancyVulnerableAbi = [
  "function deposit() payable",
  "function withdraw() public"
];
const reentrancyVulnerableAddress = process.env.REENTRANCY_VULNERABLE_CONTRACT;
const reentrancyVulnerableContract = new ethers.Contract(reentrancyVulnerableAddress, reentrancyVulnerableAbi);



const reentrancyAttacker = new ethers.Wallet(process.env.ATTACKER_PRIVATE_KEY, provider);
const reentrancyAttackerAddress = reentrancyAttacker.address;
const reentrancyAttackAbi = [
  "function deposit() payable",
  "function withdraw()",
  `function withdrawWithAttestation(
    (uint256 deadline, bytes32[] executionHashes) calldata attestation,
    bytes calldata attestationSignature
  ) payable`,
  "function attack() payable",
  `function attackWithAttestation(
    (uint256 deadline, bytes32[] executionHashes) calldata attestation,
    bytes calldata attestationSignature
  ) payable`,
  "function withdrawFunds()"
];
const reentrancyAttackAddress = process.env.REENTRANCY_ATTACK_CONTRACT;
const reentrancyAttackContract = new ethers.Contract(reentrancyAttackAddress, reentrancyAttackAbi);


const vulnDepositCall = reentrancyVulnerableContract.interface.encodeFunctionData("deposit");
const vulnWithdrawCall = reentrancyVulnerableContract.interface.encodeFunctionData("withdraw");
const depositCall = reentrancyAttackContract.interface.encodeFunctionData("deposit");
const withdrawCall = reentrancyAttackContract.interface.encodeFunctionData("withdraw");
const attackCall = reentrancyAttackContract.interface.encodeFunctionData("attack");
const withdrawFundsCall = reentrancyAttackContract.interface.encodeFunctionData("withdrawFunds");

module.exports = {
    attesterUrl,
    jsonRpcUrl,
    provider,
    oneEthInHex,
    reentrancyVictim,
    reentrancyVictimAddress,
    reentrancyVulnerableAbi,
    reentrancyVulnerableAddress,
    reentrancyVulnerableContract,
    reentrancyAttacker,
    reentrancyAttackerAddress,
    reentrancyAttackAbi,
    reentrancyAttackAddress,
    reentrancyAttackContract,
    vulnDepositCall,
    vulnWithdrawCall,
    depositCall,
    withdrawCall,
    attackCall,
    withdrawFundsCall
}