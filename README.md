# Build SSM Env Action

A GitHub Action that loads AWS SSM Parameter Store values under a given path prefix into a `.env` file in the workspace, ready for consumption by subsequent workflow steps.

It authenticates to AWS via OIDC (no long-lived access keys), downloads a checksum-verified, pinned build of [`Droplr/aws-env`](https://github.com/Droplr/aws-env), and exports every parameter under `AWS_ENV_PATH` in `dotenv` format.

## Requirements

### Permissions

Your workflow must include these permissions for OIDC authentication:

```yaml
permissions:
  id-token: write   # Required for AWS OIDC authentication
  contents: read    # Required for actions/checkout
```

### AWS IAM Role

The assumed role must:

1. Trust GitHub's OIDC provider.
2. Grant read access to the SSM parameters you want to load (`ssm:GetParametersByPath`, plus `kms:Decrypt` when SecureString parameters are used).

Minimal IAM policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["ssm:GetParametersByPath", "ssm:GetParameters"],
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

### Supported Runners

- `ubuntu-24.04` (recommended)
- `ubuntu-22.04`
- `ubuntu-latest`

### Dependencies

- `curl`, `sha256sum`, and `bash` (pre-installed on GitHub-hosted runners)
- Internal: `aws-actions/configure-aws-credentials@v6`

## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `AWS_ROLE_TO_ASSUME` | ARN of the IAM role to assume via OIDC | Yes | — |
| `AWS_REGION` | AWS region where SSM parameters live | Yes | — |
| `AWS_ROLE_DURATION_SECONDS` | Duration in seconds for the assumed role session | Yes | — |
| `AWS_ENV_PATH` | SSM parameter path prefix to load (e.g. `/my-app/prod/`) | Yes | — |

## Outputs

This action does not produce outputs. It writes a `.env` file to the current working directory.

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
        uses: heronlabs/action-ssm-env-build@v2
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

## Notes

- **Pinned `aws-env`**: the underlying binary is fetched from a specific upstream commit and its SHA-256 is verified before execution. Bumping the binary means updating both constants in `core/ssm-to-env.sh` together.
- **`.env` location**: the file is written to the current working directory — typically the repo root after `actions/checkout`.

## License

MIT
