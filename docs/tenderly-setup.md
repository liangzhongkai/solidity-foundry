# Tenderly Setup

This repository includes a starter Tenderly layout for alert-driven monitoring:

- `tenderly.yaml.example`
- `tenderly/actions/notify.ts`
- `.github/workflows/deploy-tenderly-actions.yml`

## Goal

Use Tenderly alerts to watch the deployed `Wallet` contract for:

- large balance changes
- privileged calls such as `withdraw` or `setOwner`
- failed transactions against the monitored contracts

## Repository values

Store these in GitHub before automating deployment of Tenderly actions:

- Secret: `TENDERLY_ACCESS_KEY`
- Variable: `TENDERLY_ACCOUNT_SLUG`
- Variable: `TENDERLY_PROJECT_SLUG`
- Secret: `SLACK_WEBHOOK_URL` if you want Slack delivery from the sample action

## Tenderly dashboard setup

1. Create or choose a Tenderly project.
2. Create alerts for the `Wallet` contract and conditions you care about.
3. Copy the generated alert IDs.
4. Replace the placeholder IDs in `tenderly.yaml.example`.
5. Rename the file to `tenderly.yaml` when you are ready to deploy it.

## Wallet-focused alert rules

Recommended first rules for `Wallet`:

- `wallet-large-balance-change`: alert when native balance decreases or increases more than your chosen threshold
- `wallet-privileged-call`: alert on calls to `withdraw(uint256)` or `setOwner(address)`
- `wallet-failed-transaction`: alert on failed transactions targeting the `Wallet` contract

Useful identifiers:

- `withdraw(uint256)` selector: `0x2e1a7d4d`
- `setOwner(address)` selector: `0x13af4035`
- critical event names: `Withdrawal`, `OwnerChanged`

Suggested thresholds for a demo wallet:

- low traffic demo: alert on any outbound withdrawal
- staging environment: alert on balance delta above `0.1 ETH`
- higher noise environment: alert on balance delta above `1 ETH`

## Example deployment flow

```bash
export TENDERLY_ACCESS_KEY=...
export TENDERLY_ACCOUNT_SLUG=...
export TENDERLY_PROJECT_SLUG=...

tenderly login --access-key "$TENDERLY_ACCESS_KEY"
tenderly actions deploy
```

You can also deploy through GitHub Actions with:

- workflow: `Deploy Tenderly Actions`
- config path: `tenderly.yaml`

The workflow can render `${TENDERLY_ACCOUNT_SLUG}` and `${TENDERLY_PROJECT_SLUG}` placeholders from GitHub Actions variables before deploying.

## Notes

- The sample action posts a compact message to Slack when a Tenderly alert triggers it.
- If `SLACK_WEBHOOK_URL` is not configured, the sample action logs the event payload instead.
- You should tailor the alert expressions in Tenderly to the specific contract address and function selectors you want to monitor.
- The workflow does not invent alert IDs for you; those must come from the Tenderly dashboard after you create the alerts.
