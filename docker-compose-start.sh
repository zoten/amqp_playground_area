#!/bin/bash

set -e

mkdir -p $PWD/data/rabbitmq0/data
mkdir -p $PWD/data/rabbitmq0/log
chmod -R 777 $PWD/data

docker-compose up -d
