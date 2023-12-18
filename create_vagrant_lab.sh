#!/usr/bin/env bash

if [ $# -ne 1 ]; then
 echo "Exactly one argument is required. The name of the lab. Exiting ..."
 exit 1
fi

VAGRANT_ANSIBLE_FILE="../Vagrantfile"

dir="$(pwd)/${1}"

mkdir -p "${dir}"

cd "${dir}"

ln -s ../ansible . 2> /dev/null
ln -s ../scripts . 2> /dev/null
ln -s "$VAGRANT_ANSIBLE_FILE"  "$dir/Vagrantfile" 2> /dev/null

if ! test -f "${dir}/vagrant-ansible-provision.conf.rb"; then
  cat > "${dir}/vagrant-ansible-provision.conf.rb" << EOF
\$LAB="${1}"
\$SETTINGS_FILE="#{VAGRANTFILE_DIR}/../servers.yml"
\$ENVIRONMENT_FILE="#{VAGRANTFILE_DIR}/../environment.yml"

EOF
fi
