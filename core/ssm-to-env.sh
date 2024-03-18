#!/bin/bash

wget https://github.com/Droplr/aws-env/raw/master/bin/aws-env-linux-amd64 -O aws-env

echo $AWS_REGION
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY
echo $AWS_ENV_PATH

eval $(./aws-env --recursive --format=dotenv > .env)
