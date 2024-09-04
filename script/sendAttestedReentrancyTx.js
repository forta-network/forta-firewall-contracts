const axios = require('axios');
require('dotenv/config');
const { ethers } = require('ethers');

const attesterUrl = process.env.ATTESTER_URL;

const jsonRpcUrl = process.env.ETH_SEPOLIA_RPC_URL;
const chainId = 11155111; // Ethereum Sepolia
const provider = new ethers.JsonRpcProvider(jsonRpcUrl);
const reentrancyAttacker = new ethers.Wallet(process.env.ATTACKER_PRIVATE_KEY, provider);
const reentrancyAttackerAddress = reentrancyAttacker.address;

const reentrancyAttackAbi = [
  "function attack() payable",
  `function attackWithAttestation(
    (uint256 deadline, bytes32[] executionHashes) calldata attestation,
    bytes calldata attestationSignature
  ) public payable`,
  "function withdrawFunds()"
];

const reentrancyAttackAddress = process.env.REENTRANCY_ATTACK_CONTRACT;
const reentrancyAttackContract = new ethers.Contract(reentrancyAttackAddress, reentrancyAttackAbi);

const attackCall = reentrancyAttackContract.interface.encodeFunctionData("attack");

async function main() {
    try {
      await reentrancyAttacker.call({
        to: reentrancyAttackAddress,
        data: attackCall,
        gasLimit: 200000,
        value: ethers.parseEther("1")
      });
    } catch (err) {
      console.log(`tx really fails without the attestation for 'withdraw' in 'ReentrancyVulnerable': ${err}`);
    }
  
    const result = await axios.post(attesterUrl,
      {
        from: reentrancyAttackerAddress,
        to: reentrancyAttackAddress,
        input: attackCall,
        chainId: chainId,
        
        // Integration testing params:
        disableScreening: true,
        jsonRpcUrl,
      }
    );
  
    console.log(`got attestation result:`);
    console.log(result.data);

    // To see the `result` of when an attestion _wouldn't_ (it shouldn't have been) be submitted.
    // console.log(`result: ${JSON.stringify(result)}`);
  
    const { attestation, signature } = result.data;
    const attackWithAttestationCall = reentrancyAttackContract.interface.encodeFunctionData("attackWithAttestation", [attestation, signature]);

    let isAttackWithAttestationCallSuccess = false;
  
    try {
        await reentrancyAttacker.call({
          to: reentrancyAttackAddress,
          data: attackWithAttestationCall,
          gasLimit: 200000,
          value: ethers.utils.parseEther("1")
        });
        console.log('tx will succeed with the attestation! no eth_call failure.');

        const txResult = await reentrancyAttacker.sendTransaction({
            to: reentrancyAttackAddress,
            data: attackWithAttestationCall,
            gasLimit: 200000,
            value: ethers.utils.parseEther("1")
        });
        console.log(`transaction sent with attestation: ${txResult.hash}`);

        isAttackWithAttestationCallSuccess = true;
    } catch (err) {
        console.log(`tx still fails without the attestation even after submitting txn to Attester: ${err}`);
    }
  
    const withdrawFundsCall = reentrancyAttackContract.interface.encodeFunctionData("withdrawFunds", []);
    if(isAttackWithAttestationCallSuccess) {
        try {
            console.log(`ETH balance of reentrancyAttackerAddress BEFORE 'withdrawFunds(): ${await reentrancyAttacker.getBalance()}`);

            const txResult = await reentrancyAttacker.sendTransaction({
                to: reentrancyAttackAddress,
                data: withdrawFundsCall,
                gasLimit: 200000
            });
            console.log(`transaction sent to withdraw funds: ${txResult.hash}`);

            console.log(`ETH balance of reentrancyAttackerAddress AFTER 'withdrawFunds(): ${await reentrancyAttacker.getBalance()}`);
        } catch (err) {
            console.log(`withdrawing funds tx fails: ${err}`);
        }
    }
  }

main();