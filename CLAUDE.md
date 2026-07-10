<!-- supera:guardrails -->
## Working with this repo (managed by /start — edits between these markers are overwritten on re-run)

- **Edit, don't rewrite.** Change only the needed entry in a config/generated file; preserve the rest.
- **No scope creep.** Build only what was asked; no speculative abstractions.
- **Ambiguous literals: flag, don't guess.** Config keys, IDs, env names can be literal values.
- **Scope a change to where it belongs** — most changes are localized to one area.
<!-- /supera:guardrails -->

## Stack
- **Runtime**: Bash (composite GitHub Action)
- **Test framework**: [BATS](https://github.com/bats-core/bats-core) — `tests/action.bats`
- **Linter**: [shellcheck](https://www.shellcheck.net/) — all shell scripts + test files
- **Entry point**: `core/ssm-to-env.sh` — invoked by `action.yml` composite step

## Commands
| Command | Description |
|---------|-------------|
| `make test` | Run BATS tests |
| `make lint` | Run shellcheck on all shell scripts |

## Key files
| File | Purpose |
|------|---------|
| `action.yml` | Composite action definition (inputs, outputs, steps) |
| `core/ssm-to-env.sh` | SSM parameter to .env script |
| `tests/action.bats` | BATS integration tests |
| `tests/__mocks__/node` | Node.js stub |
| `tests/__mocks__/npx` | npx stub |
| `Makefile` | Test + lint targets |
| `version.txt` | Current semver version |
| `CHANGELOG.md` | Release history |
