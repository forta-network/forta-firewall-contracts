const axios = require('axios');
require('dotenv/config');
const { ethers } = require('ethers');

// Booleans to decide which transaction to be
// executed: benign and/or malicious
const executeBenignDepositAndWithdraw = true;
const executeMaliciousReentrancy = true;


const attesterUrl = process.env.ATTESTER_URL;


const jsonRpcUrl = process.env.ETH_SEPOLIA_RPC_URL;
const chainId = 11155111; // Ethereum Sepolia
const provider = new ethers.JsonRpcProvider(jsonRpcUrl);


const reentrancyVictim = new ethers.Wallet(process.env.VICTIM_PRIVATE_KEY, provider);
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
const depositCall = reentrancyAttackContract.interface.encodeFunctionData("deposit");
const withdrawCall = reentrancyAttackContract.interface.encodeFunctionData("withdraw");
const attackCall = reentrancyAttackContract.interface.encodeFunctionData("attack");
const withdrawFundsCall = reentrancyAttackContract.interface.encodeFunctionData("withdrawFunds");;

async function main() {

    if(executeBenignDepositAndWithdraw) {
      console.log(`ETH balance of reentrancy attacker EOA BEFORE benign 'deposit(): ${
        ethers.formatEther(await provider.getBalance(reentrancyAttacker))
      }`);

      let txResult = await reentrancyAttacker.sendTransaction({
        to: reentrancyAttackAddress,
        data: depositCall,
        gasLimit: 200000,
        value: ethers.parseEther("3")
      });
      await txResult.wait();

      console.log(`benign 'deposit()' transaction sent with hash: ${txResult.hash}`);
      console.log(`ETH balance of reentrancy attacker EOA AFTER benign 'deposit(): ${
        ethers.formatEther(await provider.getBalance(reentrancyAttacker))
      }`);

      let withdrawToBeSuccessful;
      try {
        // Should not be successful because lack of attestation
        await reentrancyAttacker.call({
          to: reentrancyAttackAddress,
          data: withdrawCall,
          gasLimit: 200000,
        });

        withdrawToBeSuccessful = true;
      } catch (err) {
        console.log(`benign 'withdraw()' tx fails without the attestation: ${err}`);
      }

      let result;
      if(withdrawToBeSuccessful) {
        // This block shouldn't execute because lack of attestation,
        // but included nonetheless
        const txResult = await reentrancyAttacker.sendTransaction({
            to: reentrancyAttackAddress,
            data: withdrawCall,
            gasLimit: 200000
        });
        await txResult.wait();

        console.log(`benign 'withdraw()' transaction sent with hash: ${txResult.hash}`);
        console.log(`ETH balance of reentrancy attacker EOA BEFORE benign 'withdrawFunds(): ${
          ethers.formatEther(await provider.getBalance(reentrancyAttacker))
        }`);

        txResult = await reentrancyAttacker.sendTransaction({
            to: reentrancyAttackAddress,
            data: withdrawFundsCall,
            gasLimit: 200000
        });
        await txResult.wait();

        console.log(`'withdrawFunds()' transaction sent with hash: ${txResult.hash}`);
        console.log(`ETH balance of reentrancy attacker EOA AFTER 'withdrawFunds(): ${
          ethers.formatEther(await provider.getBalance(reentrancyAttacker))
        }`);
      } else {
        result = await axios.post(attesterUrl,
          {
            from: reentrancyAttackerAddress,
            to: reentrancyAttackAddress,
            input: withdrawCall,
            chainId: chainId,
            
            // Integration testing params:
            disableScreening: true,
            jsonRpcUrl,
          }
        );

        console.log(`got attestation result:`);
        console.log(result.data);

        const { attestation, signature } = result.data;
        const withdrawWithAttestationCall = reentrancyAttackContract.interface.encodeFunctionData(
          "withdrawWithAttestation",
          [attestation, signature]
        );

        let withdrawWithAttestationSuccessful;
        try {
            await reentrancyAttacker.call({
              to: reentrancyAttackAddress,
              data: withdrawWithAttestationCall,
              gasLimit: 200000
            });
            console.log(`benign 'withdrawWithAttestation()' tx will succeed with the attestation! no eth_call failure.`);

            let txResult = await reentrancyAttacker.sendTransaction({
                to: reentrancyAttackAddress,
                data: withdrawWithAttestationCall,
                gasLimit: 200000
            });
            await txResult.wait();
            console.log(`'withdrawWithAttestation()' transaction sent with hash: ${txResult.hash}`);

            withdrawWithAttestationSuccessful = true;
        } catch (err) {
            console.log(`benign 'withdrawWithAttestation()' tx still fails without the attestation even after submitting txn to Attester: ${err}`);
        }

        if(withdrawWithAttestationSuccessful) {
          try {
            console.log(`ETH balance of reentrancy attacker EOA BEFORE benign 'withdrawFunds(): ${
              ethers.formatEther(await provider.getBalance(reentrancyAttacker))
            }`);

            txResult = await reentrancyAttacker.sendTransaction({
                to: reentrancyAttackAddress,
                data: withdrawFundsCall,
                gasLimit: 200000
            });
            await txResult.wait();

            console.log(`'withdrawFunds()' transaction sent with hash: ${txResult.hash}`);
            console.log(`ETH balance of reentrancy attacker EOA AFTER benign 'withdrawFunds(): ${
              ethers.formatEther(await provider.getBalance(reentrancyAttacker))
            }`);
          } catch (err) {
            console.log(`'withdrawFunds()' after 'withdrawWithAttestation()' tx fails with: ${err}`);
          }
        }
      }
    }

    if(executeMaliciousReentrancy) {
      console.log(`ETH balance of reentrancy victim EOA BEFORE benign 'deposit(): ${
        ethers.formatEther(await provider.getBalance(reentrancyVictim))
      }`);

      txResult = await reentrancyVictim.sendTransaction({
        to: reentrancyVulnerableAddress,
        data: vulnDepositCall,
        gasLimit: 200000,
        value: ethers.parseEther("5")
      });
      await txResult.wait();

      console.log(`benign 'deposit()' transaction sent with hash: ${txResult.hash}`);
      console.log(`ETH balance of reentrancy victim EOA AFTER benign 'deposit(): ${
        ethers.formatEther(await provider.getBalance(reentrancyVictim))
      }`);

      try {
        // Should error out due to lack of attestation
        const txResult = await reentrancyAttacker.sendTransaction({
          to: reentrancyAttackAddress,
          data: attackCall,
          gasLimit: 200000,
          value: ethers.parseEther("1")
        });
        await txResult.wait();

        console.log(`malicious 'attack()' transaction sent with hash: ${txResult.hash}`);
      } catch (err) {
        console.log(`malicious 'attack()' transaction failed with: ${err}`);
      }
    
      result = await axios.post(attesterUrl,
        {
          from: reentrancyAttackerAddress,
          to: reentrancyAttackAddress,
          input: attackCall,
          chainId: chainId,
          // 1 ETH in hexadecimal 
          // with leading zero removed
          value: "0xde0b6b3a7640000",
          
          // Integration testing params:
          disableScreening: true,
          jsonRpcUrl,
        }
      );
    
      console.log(`got attestation result:`);
      console.log(result.data);

      const { attestation, signature } = result.data;
      const attackWithAttestationCall = reentrancyAttackContract.interface.encodeFunctionData(
        "attackWithAttestation",
        [attestation, signature]
      );

      let isAttackWithAttestationCallSuccess = false;
      try {
          await reentrancyAttacker.call({
            to: reentrancyAttackAddress,
            data: attackWithAttestationCall,
            gasLimit: 200000,
            value: ethers.parseEther("1")
          });
          console.log(`malicious 'attackWithAttestation()' tx will succeed with the attestation! no eth_call failure.`);

          console.log(`ETH balance of 'ReentrancyAttack' contract BEFORE 'attackWithAttestation()': ${
            ethers.formatEther(await provider.getBalance(reentrancyAttackContract))
          }`);

          const txResult = await reentrancyAttacker.sendTransaction({
              to: reentrancyAttackAddress,
              data: attackWithAttestationCall,
              gasLimit: 200000,
              value: ethers.parseEther("1")
          });
          await txResult.wait();

          console.log(`malicious 'attackWithAttestation()' transaction sent with hash: ${txResult.hash}`);
          console.log(`ETH balance of 'ReentrancyAttack' contract AFTER 'attackWithAttestation()': ${
            ethers.formatEther(await provider.getBalance(reentrancyAttackContract))
          }`);

          isAttackWithAttestationCallSuccess = true;
      } catch (err) {
          console.log(`'attackWithAttestation()' tx still fails without the attestation even after submitting txn to Attester: ${err}`);
      }
    
      if(isAttackWithAttestationCallSuccess) {
          try {
              console.log(`ETH balance of reentrancy attacker EOA BEFORE 'withdrawFunds()': ${
                ethers.formatEther(await provider.getBalance(reentrancyAttacker))
              }`);

              const txResult = await reentrancyAttacker.sendTransaction({
                  to: reentrancyAttackAddress,
                  data: withdrawFundsCall,
                  gasLimit: 200000
              });
              await txResult.wait();

              console.log(`malicious 'withdrawFunds()' transaction sent with hash: ${txResult.hash}`);
              console.log(`ETH balance of reentrancy attacker EOA AFTER 'withdrawFunds()': ${
                ethers.formatEther(await provider.getBalance(reentrancyAttacker))
              }`);
          } catch (err) {
              console.log(`malicious 'withdrawFunds()' tx fails: ${err}`);
          }
      }
    }
  }

main();