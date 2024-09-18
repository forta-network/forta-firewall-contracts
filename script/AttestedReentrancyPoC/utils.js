const { ethers } = require('ethers');

async function logEthBalance(addrName, funcName, beforeOrAfter, account, provider) {
    console.log(`\nETH balance of ${addrName} ${beforeOrAfter} ${funcName}: ${
        ethers.formatEther(await provider.getBalance(account))
    }\n`);
}

async function simulateTransactionWithCall(from, to, data, value, funcName) {
    await from.call({
      to,
      data,
      gasLimit: 300000, // Commented out to let `ethers` use `estimateGas`
      value
    });
    console.log(`\n${funcName} tx will succeed with the attestation! no eth_call failure.\n`);
}

async function sendTransaction(from, to, data, value, funcName, loggedAddrName, loggedAccountBalance, provider) {
    await logEthBalance(loggedAddrName, funcName, "before", loggedAccountBalance, provider);
    const txResult = await from.sendTransaction({
        to,
        data,
        gasLimit: 300000, // Comment out to let `ethers` use `estimateGas`
        value
    });
    await txResult.wait();
    console.log(`\n${funcName} transaction sent with hash: ${txResult.hash}\n`);
    await logEthBalance(loggedAddrName, funcName, "after", loggedAccountBalance, provider);
}

module.exports = {
    simulateTransactionWithCall,
    sendTransaction
}