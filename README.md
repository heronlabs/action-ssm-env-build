# SSM Env Build Action

[![CI](https://github.com/heronlabs/action-ssm-env-build/actions/workflows/ci.yml/badge.svg)](https://github.com/heronlabs/action-ssm-env-build/actions/workflows/ci.yml)

> Load AWS SSM Parameter Store values under a path prefix into a `.env` file for later workflow steps.

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
      - uses: actions/checkout@v6

      - name: Load SSM env
        uses: heronlabs/action-ssm-env-build@v3
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

## Notes

- Flat load only — one level under `AWS_ENV_PATH`; nested paths are not traversed.
- `.env` is written to the current working directory (run after `actions/checkout`, typically repo root).
- SecureString params require `kms:Decrypt` on the encrypting KMS key.
- Node and bash are pre-installed on GitHub-hosted runners; no `setup-node` needed.

## License

MIT
