# 🔐 action-ssm-env-build — Load SSM params to .env

[![CI][ci-badge]][ci-url]
[![License: MIT][license-badge]][license-url]
[![GitHub Marketplace][marketplace-badge]][marketplace-url]

> **GitHub Action** to load AWS SSM Parameter Store values under a path prefix into a `.env` file for later workflow steps.

## Contents

- [Usage](#usage)
- [Inputs](#inputs)
- [Outputs](#outputs)
- [Permissions](#permissions)
- [Architecture](#architecture)
- [How it works](#how-it-works)
- [Notes](#notes)
- [License](#license)

Authenticates to AWS via OIDC (no long-lived keys), then writes every parameter one level under `AWS_ENV_PATH` to a `.env` file in `dotenv` format in the working directory.

## Usage

```yaml
name: Deploy

on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7

      - name: Load SSM env
        uses: heronlabs/action-ssm-env-build@v4
        with:
          AWS_ROLE_TO_ASSUME: ${{ secrets.AWS_ROLE_ARN }}
          AWS_REGION: us-east-1
          AWS_ROLE_DURATION_SECONDS: 900
          AWS_ENV_PATH: /my-app/prod/

      - name: Use loaded env
        run: |
          set -a
          . ./.env
          set +a
          ./deploy.sh
```

## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `AWS_ROLE_TO_ASSUME` | ARN of the IAM role to assume via OIDC for SSM access. | Yes | — |
| `AWS_REGION` | AWS region where the SSM parameters live. | Yes | — |
| `AWS_ROLE_DURATION_SECONDS` | Duration in seconds for the assumed role session. | Yes | — |
| `AWS_ENV_PATH` | SSM parameter path prefix to load (e.g. `/my-app/prod/`). | Yes | — |

## Outputs

This action produces no GitHub outputs. It writes a `.env` file to the working directory (one var per SSM parameter one level under `AWS_ENV_PATH`, dotenv format).

## Permissions

```yaml
permissions:
  id-token: write
  contents: read
```

<details><summary>AWS IAM policy</summary>

The assumed role must trust GitHub's OIDC provider and grant read access to the parameters you load. `kms:Decrypt` is required for SecureString parameters.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ssm:GetParametersByPath",
      "Resource": "arn:aws:ssm:<region>:<account-id>:parameter/<path-prefix>*"
    },
    {
      "Effect": "Allow",
      "Action": "kms:Decrypt",
      "Resource": "arn:aws:kms:<region>:<account-id>:key/<key-id>"
    }
  ]
}
```

</details>

## Architecture

Bash shell script wrapped by a composite GitHub Action.

```
├── action.yml                    # Composite action definition
├── core/
│   └── ssm-to-env.sh             # CLI entry point — SSM parameter to .env
├── tests/
│   ├── __mocks__/
│   │   ├── node                  # Node.js stub
│   │   └── npx                   # npx stub
│   └── action.bats               # BATS tests
├── Makefile                      # test (bats) + lint (shellcheck)
└── version.txt                   # Current version
```

## How it works

Composite action with a single shell script (`core/ssm-to-env.sh`):

1. **Authenticate** — `aws-actions/configure-aws-credentials` assumes the caller's IAM role via OIDC.
2. **Fetch parameters** — the script fetches a pinned version of `@heronlabs/env-ssm` via `npx`, which loads every SSM parameter one level under `AWS_ENV_PATH` and writes them to `.env` in dotenv format.

## Notes

- Flat load only — one level under `AWS_ENV_PATH`; nested paths are not traversed.
- `.env` is written to the current working directory (run after `actions/checkout`, typically repo root).
- SecureString params require `kms:Decrypt` on the encrypting KMS key.
- Node and bash are pre-installed on GitHub-hosted runners; no `setup-node` needed.

## License

MIT

[ci-badge]: https://github.com/heronlabs/action-ssm-env-build/actions/workflows/continuous-integration.yml/badge.svg
[ci-url]: https://github.com/heronlabs/action-ssm-env-build/actions/workflows/continuous-integration.yml
[license-badge]: https://img.shields.io/badge/License-MIT-blue.svg
[license-url]: ./LICENSE
[marketplace-badge]: https://img.shields.io/badge/GitHub-Marketplace-green.svg
[marketplace-url]: https://github.com/marketplace/actions/action-ssm-env-build
