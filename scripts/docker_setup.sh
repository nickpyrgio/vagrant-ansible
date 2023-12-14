#!/usr/bin/env bash

DEBIAN_FRONTEND=noninteractive apt update
apt -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --assume-yes install docker docker-compose
echo Hello World quotes \"\"
