#!/bin/bash

set -e

wget https://github.com/Droplr/aws-env/raw/master/bin/aws-env-linux-amd64 -O aws-env
chmod +x aws-env

SESSION=$(aws sts assume-role \
--role-arn "$AWS_ASSUME_ROLE" \
--role-session-name "$AWS_ASSUME_ROLE_SESSION" \
--query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
--output text)

export AWS_ACCESS_KEY_ID=$(echo $SESSION | cut -d' ' -f1)
export AWS_SECRET_ACCESS_KEY=$(echo $SESSION | cut -d' ' -f2)
export AWS_SESSION_TOKEN=$(echo $SESSION | cut -d' ' -f3)

eval $(./aws-env --recursive --format=dotenv > .env)

export AWS_ACCESS_KEY_ID=''
export AWS_SECRET_ACCESS_KEY=''
export AWS_SESSION_TOKEN=''
