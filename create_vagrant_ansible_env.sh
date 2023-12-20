#!/usr/bin/env bash

VAGRANT_ENV_DIR="../vagrant"
VAGRANT_PROJECT_DIR_NAME="vagrant-ansible"
mkdir -p \
    ${VAGRANT_ENV_DIR}

cd ${VAGRANT_ENV_DIR}
VAGRANT_ENV_DIR=`pwd`

ln -sf ../${VAGRANT_PROJECT_DIR_NAME}/Vagrantfile .
ln -sf ../${VAGRANT_PROJECT_DIR_NAME}/create_vagrant_lab.sh .
ln -sf ../${VAGRANT_PROJECT_DIR_NAME}/run_labs.sh .
if ! test -f ${VAGRANT_ENV_DIR}/servers.yml; then
  cp ../${VAGRANT_PROJECT_DIR_NAME}/servers.yml.dist servers.yml
fi

if ! test -f ${VAGRANT_ENV_DIR}/vagrant-ansible-provision.conf.rb; then
  cp ../${VAGRANT_PROJECT_DIR_NAME}/vagrant-ansible-provision.conf.rb.dist vagrant-ansible-provision.conf.rb
fi
