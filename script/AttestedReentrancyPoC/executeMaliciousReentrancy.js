const axios = require('axios');
const { ethers } = require('ethers');
const {
    reentrancyVictim,
    reentrancyVictimAddress,
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
    simulateTransactionWithCall,
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
  
    let attackAttestationRequestSuccessful, attackWithAttestationCall, attestationRequestResult;
    try {
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

      attestationRequestResult = await axios.post(attesterUrl,
        attestationRequestObj
      );

      attackAttestationRequestSuccessful = true;
  
      console.log(`\ngot attestation result:`);
      console.log(attestationRequestResult.data);

      const { attestation, signature } = attestationRequestResult.data;
      attackWithAttestationCall = reentrancyAttackContract.interface.encodeFunctionData(
        "attackWithAttestation",
        [attestation, signature]
      );

    } catch (err) {
      console.log(`\nrequest for attestation failed with: ${err}\n\nattestation request result: ${attestationRequestResult}\n`);
    }

    if(attackAttestationRequestSuccessful) {
      let attackWithAttestationCallSuccessful;

      try {
        await simulateTransactionWithCall(
            reentrancyAttacker,
            reentrancyAttackAddress,
            attackWithAttestationCall,
            ethers.parseEther("1"),
            "malicious 'attackWithAttestation()'"
        );

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
        let maliciousWithdrawFundsSuccessful;

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
      }
    } else { // Withdraw ETH from `ReentrancyVulnerable` by Victim EOA

      let vulnWithdrawToBeSuccessful;
      try {
        // Should not be successful because lack of attestation
        await simulateTransactionWithCall(
            reentrancyVictim,
            reentrancyVulnerableAddress,
            vulnWithdrawCall,
            0,
            "vulnerable 'withdraw()'"
        );
        vulnWithdrawToBeSuccessful = true;
      } catch (err) {
        console.log(`vulnerable 'withdraw()' tx fails without the attestation: ${err}`);
      }

      if(vulnWithdrawToBeSuccessful) {
        // This block shouldn't execute because lack of attestation,
        // but included nonetheless
        await sendTransaction(
            reentrancyVictim,
            reentrancyVulnerableAddress,
            vulnWithdrawCall,
            0,
            "vulnerable 'withdraw()'",
            "reentrancy victim EOA",
            reentrancyVictim,
            provider
        );
      } else {

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

            const result = await axios.post(attesterUrl,
                attestationRequestObj
            );

            vulnWithdrawAttestationRequestSuccessful = true

            console.log(`\ngot attestation result:\n${result.data}\n`);

            const { attestation, signature } = result.data;
            // Using `attestedCall()`, like `attackWithAttestation` in the `ReentrancyAttack` contract does.
            vulnWithdrawCallWithAttestation = reentrancyAttackContract.interface.encodeFunctionData(
                "attestedCall",
                [attestation, signature, vulnWithdrawCall]
            );
        } catch (err) {
            console.log(`\nrequest for attestation failed with:\n${err}\n`);
        }

        if(vulnWithdrawAttestationRequestSuccessful) {
            try {
                await simulateTransactionWithCall(
                    reentrancyVictim,
                    reentrancyVulnerableAddress,
                    vulnWithdrawCallWithAttestation,
                    0,
                    "vulnerable 'withdraw()' with attestation"
                );

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
        }
      }
    }    
}

module.exports = {
    executeMaliciousReentrancy
}