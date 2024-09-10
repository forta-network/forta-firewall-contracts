const {
  executeBenignDepositAndWithdraw
} = require('./executeBenignDepositAndWithdraw');
const {
  executeMaliciousReentrancy
} = require('./executeMaliciousReentrancy');

// Booleans to decide which transaction flow
// to be executed: benign and/or malicious
const benignDepositAndWithdraw = true;
const maliciousReentrancy = true;

async function main() {
    if(benignDepositAndWithdraw) {
      console.log("\n\nExecuting benign deposit and withdrawal from " +
      "'ReentrancyAttack' contract to 'ReentrancyVulnerable' contract.\n\n");
      await executeBenignDepositAndWithdraw();
    }

    if(maliciousReentrancy) {
      console.log("\n\nExecuting malicious reentrancy attack from " +
      "'ReentrancyAttack' contract to 'ReentrancyVulnerable' contract.\n\n");
      await executeMaliciousReentrancy();
    }
  }

main();