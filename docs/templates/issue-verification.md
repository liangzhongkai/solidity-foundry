# Issue Verification Template

Use this file as `docs/issues/<issue-number>/verification.md`.

## Verification Summary

- Issue: `#<number> - <title>`
- Commit: `<sha>`
- Reviewer-facing status: `<ready / blocked>`

## Verification Matrix

| Agent | Check | Scope | Command | Result | Blocker |
| --- | --- | --- | --- | --- | --- |
| `DevAgent` | Targeted tests | `<changed area>` | `forge test --match-path "<path>"` | `<pass/fail>` | `yes/no` |
| `DeployAgent` | Full test suite | `repo` | `forge test` | `<pass/fail>` | `yes/no` |
| `DeployAgent` | Formatting | `repo` | `forge fmt --check` | `<pass/fail>` | `yes/no` |
| `SecurityAgent` | Static analysis | `repo or module` | `<slither command>` | `<pass/fail>` | `yes/no` |
| `SecurityAgent` | Adversarial testing | `<target>` | `<echidna or invariant command>` | `<pass/fail>` | `yes/no` |
| `ReviewAgent` | Final review gate | `<target>` | `<review method>` | `<pass/fail>` | `yes/no` |

## Command Details

### Targeted Tests

```sh
forge test --match-path "<path>"
```

Result:

- `<brief result>`

### Full Suite

```sh
forge test
```

Result:

- `<brief result>`

### Formatting

```sh
forge fmt --check
```

Result:

- `<brief result>`

### Security Checks

```sh
<slither, echidna, invariant, fork, or ffi commands>
```

Result:

- `<brief result>`

## Known Gaps

- `<checks intentionally skipped and why>`

## Reviewer Notes

- `<short list of what the human should verify from the evidence above>`
