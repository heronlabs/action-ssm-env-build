#!/usr/bin/env bash

set -euo pipefail

: "${AWS_ENV_PATH:?AWS_ENV_PATH is required}"

# Pinned version of @heronlabs/env-ssm, fetched at runtime via npx (npm provenance).
ENV_SSM_VERSION="3.2.0"

command -v node >/dev/null 2>&1 || { echo "node is required to run @heronlabs/env-ssm" >&2; exit 1; }

# Fetch every SSM parameter one level under AWS_ENV_PATH and write it to .env in
# dotenv format (NAME='value', single-quote escaped — safe to `set -a; . ./.env`).
npx --yes "@heronlabs/env-ssm@${ENV_SSM_VERSION}" --format=dotenv > .env
