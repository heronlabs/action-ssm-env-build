#!/usr/bin/env bash

set -euo pipefail

: "${AWS_ENV_PATH:?AWS_ENV_PATH is required}"

wget --quiet https://github.com/Droplr/aws-env/raw/master/bin/aws-env-linux-amd64 -O aws-env
chmod +x aws-env

./aws-env --recursive --format=dotenv > .env
