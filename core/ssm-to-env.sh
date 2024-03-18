#!/bin/bash

wget https://github.com/Droplr/aws-env/raw/master/bin/aws-env-linux-amd64 -O aws-env

eval $(./aws-env --recursive --format=dotenv > .env)
