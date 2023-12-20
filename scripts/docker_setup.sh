#!/usr/bin/env bash

DOCKER_USER="${LIBVIRTD_USER:-vagrant}"

DEBIAN_FRONTEND=noninteractive apt update

apt -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --assume-yes install docker docker-compose

usermod -a -G docker ${DOCKER_USER}