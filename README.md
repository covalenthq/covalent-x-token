# Covalent X Token (CXT)


## Setup

1. Install Foundry by following the instructions from [their repository](https://github.com/foundry-rs/foundry#installation).

2. Copy the `.env.example` file to `.env` and fill in the variables.

3. Install the dependencies by running: `npm install`. In case there is an error with the commands, run `foundryup` and try them again.

##### Compile
```bash
forge  build
```
##### Running tests
```bash
forge  test
```

## Deploy & verify



### Setup
Configure the `.env` variables.

### Deployment command

```bash
npm run deploy -- --rpc-url <RPC_URL>
```

Save all the addresses from above script output for later use.
### Fetch list of token holders in JSON file

```bash
npm  run  fetch-holders
```
### Distribute tokens

distribute tokens to all holders via MigrationManager

```bash
npm  run  distribute-tokens
```
or
```bash
npm  run  distributeCSV
```

The deployments are stored in ./broadcast

See the [Foundry Book for available options](https://book.getfoundry.sh/reference/forge/forge-create.html).