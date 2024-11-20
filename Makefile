.PHONY: deploy
deploy:
	forge script --rpc-url deploy --broadcast ./script/Deployer.s.sol

.PHONY: deploy-firewall
deploy-firewall:
	forge script \
		./script/FirewallDeployer.s.sol:FirewallDeployerScript \
		--chain 1 \
		--rpc-url deploy \
		--broadcast \
		--slow \
		--verify

.PHONY: deploy-validator
deploy-validator:
	forge script --rpc-url deploy --broadcast ./script/SecurityValidatorDeployer.s.sol

.PHONY: gas
gas:
	forge test --match-test attestationGas -vvvv

.PHONY: proxy-gas
proxy-gas:
	forge test --match-test testProxyGasChained --gas-report
	forge test --match-test testProxyGasDirect --gas-report
