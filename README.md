# Covalent X Token (CXT)

## Access Control List:

## CovalentNetworkToken.sol:
- **EMISSION_ROLE:** This role is granted to the **emissionManager**. It allows the role holders to mint new tokens.
- **CAP_MANAGER_ROLE:** This role is granted to the **protocolCouncil**. It allows the role holder to update the mint cap.
- **PERMIT2_REVOKER_ROLE:** This role is granted to the **protocolCouncil** and **emergencyCouncil**. It allows the role holders to update the permit2Enabled state, which controls whether the permit2 contract has full approval by default.

## CovalentMigration.sol:
- **MIGRATION_ROLE:** This role is granted to the **migrationManager**. It allows the role holder to migrate tokens from the old contract to the new contract.

## DefaultEmissionManager.sol:
- **EMISSION_ROLE:** This role is granted to the **emissionManager**. It allows the role holder to mint new tokens.
- **CAP_MANAGER_ROLE:** This role is granted to the **protocolCouncil**. It allows the role holder to update the mint cap.
- **PERMIT2_REVOKER_ROLE:** This role is granted to the **protocolCouncil** and **emergencyCouncil**. It allows the role holders to update the permit2Enabled state, which controls whether the permit2 contract has full approval by default.


## Installation Steps:

1. Clone the above repository
2. Install Foundry by following the instructions from [here](https://github.com/foundry-rs/foundry#installation)
    ```
    curl -L https://foundry.paradigm.xyz | bash
    ```
    then follow the steps on screen to setup `foundryup`
3. Run `foundryup` then run `npm install` 
4. Now you're ready with the setup, you can build, compile, test, deploy

### Deploy:

Steps for testing, reviewing, and deploying a smart contract to a blockchain.

1. Once the above setup is completed successfully, create an `.env` file and configure all the details as per `.env.example`.
2. For compiling and testing the contracts you can execute:
   - Compile: `forge build`,
   - Run test cases: `forge test`.
   - For detailed log of test scenarios or individual test cases, run: `forge test --match-test test_MintDelay -vvv` (replace `test_MintDelay` with other function names).
3. You will be able to see the test cases run and play with them accordingly if needed.
4. For compiling the contracts, you can run `npm run postinstall` or `npm run compile-contract-types`.
5. After successful compilation, you can deploy contracts by running `npm run deploy -- --rpc-url <RPC_URL>`.
6. After a successful deployment of the token contract, you will see 3 addresses:
    1. Covalent X Token address
    2. Covalent Migration address
    3. Default Emission Manager address
7. The deployments are stored in ./broadcast
## Migrate Old token Holders:

Procedures for transferring token holders from one contract to another, ensuring accuracy and security.

- This repo has 3 custom scripts which help us in transferring the tokens to holders.
- Under the `script` folder, we have 3 TypeScript scripts:
    - `batchTransfer.ts`
    - `batchTransferCSV.ts`
    - `GetHoldersLists.ts`
- **GetHoldersLists.ts:**
    1. Using the `ETHERSCAN_API_KEY` and `CQT address` initialized by `.env`, this script fetches all the current `CQT Holders` and creates a `holders.json` file under `script/staticFiles`.
    2. To run this script use the command `npm run fetch-holders`.
- **batchTransfer.ts:**
    1. This script fetches all the holders from the above-generated JSON file along with the balance that needs to be distributed.
    2. Has extra two features along with batch transfer as below:
    
    ```typescript
    const ignoreAddresses = ['0xb270fc573f9f9868ab11b52ae7119120f6a4471d', '0x6af3d183d225725d975c5eaa08d442dd01aad8ff'];
    const ignoreAmount = ethers.utils.parseUnits('5000', 18);
    ```
    
    - `ignoreAddresses` is an array of addresses to be excluded from the batch transfer.
    - `ignoreAmount` is a constant to exclude holders with `ignoreAmount <=` from the batch transfer (e.g., holders with 5000 or less CQT won’t receive any tokens).
    3. To run this script, use the command `npm run distribute-tokens`.
- **batchTransferCSV.ts:**
    1. This script requires providing a CSV file of holders as `Tokenholders.csv` under `script/staticFiles` and then transfers the tokens to the holders in the given CSV file.
    2. Has extra two features along with batch transfer as below:
    
    ```typescript
    const ignoreAddresses = ['0xb270fc573f9f9868ab11b52ae7119120f6a4471d', '0x6af3d183d225725d975c5eaa08d442dd01aad8ff'];
    const ignoreAmount = ethers.utils.parseUnits('100', 18);
    ```
    
    - `ignoreAddresses` is an array of addresses to be excluded from the batch transfer.
    - `ignoreAmount` is a constant to exclude holders with `ignoreAmount <=` from the batch transfer (e.g., holders with 100 or less CQT won’t receive any tokens).
    3. To run this script, use the command `npm run distributeCSV`.