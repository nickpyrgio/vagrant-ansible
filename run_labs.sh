#!/usr/bin/env bash

VAGRANT_ENV_DIR=`pwd`

for lab in "$@"
do
    cd "${VAGRANT_ENV_DIR}/${lab}" && vagrant up
done
