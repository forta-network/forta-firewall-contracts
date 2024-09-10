const axios = require('axios');
const { ethers } = require('ethers');
const {
    reentrancyAttacker,
    reentrancyAttackerAddress,
    reentrancyAttackAddress,
    depositCall,
    provider,
    withdrawCall,
    withdrawFundsCall,
    attesterUrl,
    jsonRpcUrl,
    reentrancyAttackContract
} = require('./setup');
const {
  simulateTransactionWithCall,
  sendTransaction
} = require('./utils');

async function executeBenignDepositAndWithdraw() {
  await sendTransaction(
    reentrancyAttacker,
    reentrancyAttackAddress,
    depositCall,
    ethers.parseEther("3"),
    "benign 'deposit()'",
    "reentrancy attacker EOA",
    reentrancyAttacker,
    provider
  );

  let withdrawToBeSuccessful;
  try {
    // Should not be successful because lack of attestation
    await simulateTransactionWithCall(
      reentrancyAttacker,
      reentrancyAttackAddress,
      withdrawCall,
      0,
      "benign 'withdraw()'"
    );

    withdrawToBeSuccessful = true;
  } catch (err) {
    console.log(`\nbenign 'withdraw()' tx fails without the attestation: ${err}\n`);
  }

  if(withdrawToBeSuccessful) {
    // This block shouldn't execute because lack of attestation,
    // but included nonetheless
    await sendTransaction(
      reentrancyAttacker,
      reentrancyAttackAddress,
      withdrawCall,
      0,
      "'benign 'withdraw()'",
      "'ReentrancyAttack' contract",
      reentrancyAttackContract,
      provider
    );

    await sendTransaction(
      reentrancyAttacker,
      reentrancyAttackAddress,
      withdrawFundsCall,
      0,
      "'benign 'withdrawFunds()'",
      "reentrancy attacker EOA",
      reentrancyAttacker,
      provider
    );
  } else {
    const attestationRequestObj = {
      from: reentrancyAttackerAddress,
      to: reentrancyAttackAddress,
      input: withdrawCall,
      chainId: Number((await provider.getNetwork()).chainId),
      
      // Integration testing params:
      disableScreening: true,
    };

    // `jsonRpcUrl` is only needed for the sandbox API
    if (attesterUrl.includes("sandbox")) {
      attestationRequestObj.jsonRpcUrl = jsonRpcUrl;
    }
    
    const result = await axios.post(attesterUrl,
      attestationRequestObj
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
        await simulateTransactionWithCall(
          reentrancyAttacker,
          reentrancyAttackAddress,
          withdrawWithAttestationCall,
          0,
          "benign 'withdrawWithAttestation()'"
        );

        await sendTransaction(
          reentrancyAttacker,
          reentrancyAttackAddress,
          withdrawWithAttestationCall,
          0,
          "benign 'withdrawWithAttestation()'",
          "'ReentrancyAttack' contract",
          reentrancyAttackContract,
          provider
        );

        withdrawWithAttestationSuccessful = true;
    } catch (err) {
        console.log(`benign 'withdrawWithAttestation()' tx still fails with the attestation: ${err}`);
    }

    if(withdrawWithAttestationSuccessful) {
      try {
        await sendTransaction(
          reentrancyAttacker,
          reentrancyAttackAddress,
          withdrawFundsCall,
          0,
          "benign 'withdrawFunds()'",
          "reentrancy attacker EOA",
          reentrancyAttacker,
          provider
        );
      } catch (err) {
        console.log(`benign 'withdrawFunds()' tx fails with: ${err}`);
      }
    }
  }
}

module.exports = {
  executeBenignDepositAndWithdraw
}