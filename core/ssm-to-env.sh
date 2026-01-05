#!/bin/bash

set -e

wget https://github.com/Droplr/aws-env/raw/master/bin/aws-env-linux-amd64 -O aws-env
chmod +x aws-env

eval $(./aws-env --recursive --format=dotenv > .env)
