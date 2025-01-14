const axios = require('axios');
const { ethers } = require('ethers');
const {
    reentrancyVictim,
    reentrancyVictimAddress,
    reentrancyVulnerableContract,
    reentrancyVulnerableAddress,
    vulnDepositCall,
    reentrancyAttacker,
    reentrancyAttackerAddress,
    reentrancyAttackContract,
    reentrancyAttackAddress,
    attackCall,
    attesterUrl,
    oneEthInHex,
    withdrawFundsCall,
    vulnWithdrawCall,
    provider,
    jsonRpcUrl
} = require('./setup');
const {
    sendTransaction
} = require('./utils');

async function executeMaliciousReentrancy() {
    try {
      // Should error out due to lack of attestation
      await sendTransaction(
        reentrancyAttacker,
        reentrancyAttackAddress,
        attackCall,
        ethers.parseEther("1"),
        "malicious 'attack()'",
        "reentrancy attacker EOA",
        reentrancyAttacker,
        provider
    );
    } catch (err) {
      console.log(`\nmalicious 'attack()' transaction failed with: ${err}\n`);
    }
  
    let attackAttestationRequestSuccessful, attackWithAttestationCall;
    try {
      // Should error out due to `attackCall` being an exploit transaction
      const attestationRequestObj = {
        from: reentrancyAttackerAddress,
        to: reentrancyAttackAddress,
        input: attackCall,
        chainId: Number((await provider.getNetwork()).chainId),
        value: oneEthInHex
      };

      // `jsonRpcUrl` and `disableScreening` only needed for the sandbox API
      if (attesterUrl.includes("sandbox")) {
        attestationRequestObj.jsonRpcUrl = jsonRpcUrl;
        attestationRequestObj.disableScreening = true;
      }

      const attestationRequestResult = await axios.post(attesterUrl,
        attestationRequestObj
      );
  
      console.log(`\ngot attestation result:`);
      console.log(attestationRequestResult.data);

      const { attestation, signature } = attestationRequestResult.data;
      attackWithAttestationCall = reentrancyAttackContract.interface.encodeFunctionData(
        "attackWithAttestation",
        [attestation, signature]
      );

      attackAttestationRequestSuccessful = true;
    } catch (err) {
        console.log(`\n'attack()' attestation request failed with: ${err}\n`);
    }

    if(attackAttestationRequestSuccessful) {
      // Should not execute due requesting attestation for exploit transaction
      let attackWithAttestationCallSuccessful, maliciousWithdrawFundsSuccessful

      try {
        await sendTransaction(
            reentrancyAttacker,
            reentrancyAttackAddress,
            attackWithAttestationCall,
            ethers.parseEther("1"),
            "malicious 'attackWithAttestation()'",
            "'ReentrancyAttack' contract",
            reentrancyAttackContract,
            provider
        );

        attackWithAttestationCallSuccessful = true;
      } catch (err) {
        console.log(`\n'attackWithAttestation()' tx still fails with the attestation: ${err}\n`);
      }

      if(attackWithAttestationCallSuccessful) {
        try {
            await sendTransaction(
                reentrancyAttacker,
                reentrancyAttackAddress,
                withdrawFundsCall,
                0,
                "malicious 'withdrawFunds()'",
                "reentrancy attacker EOA",
                reentrancyAttacker,
                provider
            );

            maliciousWithdrawFundsSuccessful = true;
        } catch (err) {
            console.log(`\nmalicious 'withdrawFunds()' tx fails: ${err}\n`);
        }
      }

      // transfer ETH from attacker
      // to victim EOA, who then
      // deposits 5 ETH, to reset
      if(maliciousWithdrawFundsSuccessful) {
          await sendTransaction(
              reentrancyAttacker,
              reentrancyVictimAddress,
              "0x",
              ethers.parseEther("5"),
              "ETH transfer",
              "reentrancy attacker EOA",
              reentrancyAttacker,
              provider
          );

          await sendTransaction(
              reentrancyVictim,
              reentrancyVulnerableAddress,
              vulnDepositCall,
              ethers.parseEther("5"),
              "benign 'deposit()'",
              "reentrancy victim EOA",
              reentrancyVictim,
              provider
          );
      }
    } else { // Withdraw ETH from `ReentrancyVulnerable` by Victim EOA
        let vulnWithdrawAttestationRequestSuccessful, vulnWithdrawCallWithAttestation;
        try {
            const attestationRequestObj = {
              from: reentrancyVictimAddress,
              to: reentrancyVulnerableAddress,
              input: vulnWithdrawCall,
              chainId: Number((await provider.getNetwork()).chainId)
            };
      
            // `jsonRpcUrl` and `disableScreening` only needed for the sandbox API
            if (attesterUrl.includes("sandbox")) {
                attestationRequestObj.jsonRpcUrl = jsonRpcUrl;
                attestationRequestObj.disableScreening = true;
            }

            const attestationRequestResult = await axios.post(attesterUrl,
                attestationRequestObj
            );

            console.log(`\ngot attestation result:`);
            console.log(attestationRequestResult.data);

            const { attestation, signature } = attestationRequestResult.data;
            // Using `attestedCall()`, like `attackWithAttestation` in the `ReentrancyAttack` contract does.
            vulnWithdrawCallWithAttestation = reentrancyVulnerableContract.interface.encodeFunctionData(
                "attestedCall",
                [attestation, signature, vulnWithdrawCall]
            );

            vulnWithdrawAttestationRequestSuccessful = true
        } catch (err) {
            console.log(`\nvulnerable 'withdraw()' attestation request by victim EOA failed with:\n${err}\n`);
        }

        if(vulnWithdrawAttestationRequestSuccessful) {
            try {
                await sendTransaction(
                    reentrancyVictim,
                    reentrancyVulnerableAddress,
                    vulnWithdrawCallWithAttestation,
                    0,
                    "vulnerable 'withdraw()' with attestation",
                    "reentrancy victim EOA",
                    reentrancyVictim,
                    provider
                );
            } catch (err) {
                console.log(`\nvulnerable 'withdraw()' tx still fails with attestation: ${err}\n`);
            }

            // Deposit 5 ETH to set up next execution
            await sendTransaction(
                reentrancyVictim,
                reentrancyVulnerableAddress,
                vulnDepositCall,
                ethers.parseEther("5"),
                "benign 'deposit()'",
                "reentrancy victim EOA",
                reentrancyVictim,
                provider
            );
      }
    }    
}

module.exports = {
    executeMaliciousReentrancy
}