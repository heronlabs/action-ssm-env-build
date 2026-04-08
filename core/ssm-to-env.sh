#!/usr/bin/env bash

set -euo pipefail

: "${AWS_ENV_PATH:?AWS_ENV_PATH is required}"

# Pinned upstream commit of Droplr/aws-env (the repo has no releases).
# Bump the commit SHA AND the expected checksum together — never one without the other.
AWS_ENV_COMMIT="3960d830b2e27cb3ec9c065b761df627f7c55976"
AWS_ENV_SHA256="1393537837dc67d237a9a31c8b4d3dd994022d65e99c1c1e1968edc347aae63f"
AWS_ENV_URL="https://raw.githubusercontent.com/Droplr/aws-env/${AWS_ENV_COMMIT}/bin/aws-env-linux-amd64"

curl --fail --silent --show-error --location --output aws-env "${AWS_ENV_URL}"

actual_sha=$(sha256sum aws-env | awk '{print $1}')
if [ "${actual_sha}" != "${AWS_ENV_SHA256}" ]; then
  echo "aws-env checksum mismatch" >&2
  echo "  expected: ${AWS_ENV_SHA256}" >&2
  echo "  actual:   ${actual_sha}" >&2
  exit 1
fi

chmod +x aws-env

./aws-env --recursive --format=dotenv > .env
