# Blockchain CI/CD

This repository now covers most of a practical smart-contract CI/CD pipeline with GitHub Actions and Foundry.

## Current Coverage

### 1. Code commit

- `push` and `pull_request` trigger the main CI workflow.

### 2. Static analysis

- `Slither` runs in `.github/workflows/test.yml`.
- A failing high-severity Slither finding stops the pipeline.

### 3. Unit and integration testing

- `forge fmt --check`
- `forge build --sizes --build-info`
- `forge test -vvv --ffi --gas-report`
- `Echidna` fuzzing
- `Manticore` symbolic execution

The CI workflow also uploads a `gas-report` artifact so gas cost output is retained for each run.

### 4. Deployment to testnet

- `.github/workflows/deploy-sepolia.yml` deploys a Foundry script to Sepolia.
- It runs only through `workflow_dispatch`.
- It supports a custom `script_target` so deployments stay explicit and reviewable.

### 5. Verification on explorer

- The Sepolia deployment workflow can verify automatically with `--verify`.
- `.github/workflows/verify-contract.yml` supports verifying an existing deployment manually when you already have a contract address.

## GitHub Actions Configuration

Open GitHub and go to:

`Settings` -> `Secrets and variables` -> `Actions`

### Repository secrets

Add these under `Secrets`:

- `SEPOLIA_RPC_URL`
- `SEPOLIA_PRIVATE_KEY`
- `ETHERSCAN_API_KEY`
- `CERTORAKEY`
- `TENDERLY_ACCESS_KEY`

### Repository variables

Add these under `Variables`:

- `TENDERLY_ACCOUNT_SLUG`
- `TENDERLY_PROJECT_SLUG`

### What each value is for

- `SEPOLIA_RPC_URL`: Sepolia RPC endpoint from Alchemy, Infura, QuickNode, or another provider
- `SEPOLIA_PRIVATE_KEY`: deployment key for the Sepolia deployer account
- `ETHERSCAN_API_KEY`: explorer verification key for Sepolia
- `CERTORAKEY`: Certora Prover API key for `certoraRun`
- `TENDERLY_ACCESS_KEY`: Tenderly access token for CLI-based action deployment
- `TENDERLY_ACCOUNT_SLUG`: Tenderly account or team slug
- `TENDERLY_PROJECT_SLUG`: Tenderly project slug

### Recommended GitHub setup flow

1. In the repository, open `Settings`.
2. Open `Secrets and variables` -> `Actions`.
3. Create the sensitive values in the `Secrets` tab.
4. Create the non-secret identifiers in the `Variables` tab.
5. If you want production-grade separation later, move deploy-related values into a GitHub `Environment` such as `sepolia` or `staging`.

## Recommended Deployment Usage

Use `workflow_dispatch` for controlled testnet deployments.

Current default:

- `script/Counter.s.sol:CounterScript`

To deploy a different module manually, dispatch `Deploy To Sepolia` and provide a different `script_target`, for example:

- `script/DeployERC20.s.sol:DeployERC20Script`
- `script/ProxyDemo.s.sol:ProxyDemoScript`

The workflow exports both `PRIVATE_KEY` and `DEV_PRIVATE_KEY` so it can work with the existing script conventions in this repository.

## What Is Still Missing

### Certora formal verification

This repository now contains a minimal project-owned Certora baseline for `src/Wallet.sol`:

- `certora/confs/Wallet.conf`
- `certora/specs/Wallet.spec`
- `certora/specs/methods/IWallet.spec`
- `certora/specs/helpers/helpers.spec`

The current baseline proves:

- only the current owner can call `withdraw`
- only the current owner can call `setOwner`
- `owner` never becomes the zero address after deployment

The manual workflow entrypoint is `.github/workflows/formal-verification.yml`.

Example manual command input:

- `certora/confs/Wallet.conf`

This is still **not** a required CI gate yet. The next step would be expanding proofs to higher-value contracts and then making Certora mandatory in CI.

### Tenderly post-deployment monitoring

This repository now includes a Tenderly starter template:

- `tenderly.yaml.example`
- `docs/tenderly-setup.md`
- `.github/workflows/deploy-tenderly-actions.yml`

To enable real post-deployment monitoring, fill in:

- `TENDERLY_ACCESS_KEY`
- `TENDERLY_ACCOUNT_SLUG`
- `TENDERLY_PROJECT_SLUG`
- alert definitions for suspicious balance changes and unauthorized function calls
- either webhooks, Slack notifications, or Tenderly Web3 Actions

Suggested first alerts:

- large native token balance changes
- calls to privileged functions such as ownership transfer or withdrawals
- failed transactions against monitored contracts

Until those account-level details and alert IDs exist, Tenderly remains a template-backed operational setup rather than a fully active monitoring gate.

## Suggested Next Step

If you want to fully match the target pipeline, the next repository change should be:

1. extend Certora beyond `Wallet` to the contracts with real stateful risk
2. decide which script should be the canonical staging deployment target
3. replace Tenderly placeholders with real alert IDs and notification destinations
