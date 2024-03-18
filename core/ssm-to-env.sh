#!/bin/bash

wget https://github.com/Droplr/aws-env/raw/master/bin/aws-env-linux-amd64 -O aws-env

touch .env

eval $(./aws-env --recursive --format=dotenv > .env)
