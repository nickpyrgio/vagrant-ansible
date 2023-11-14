#!/usr/bin/env bash

VAGRANT_ANSIBLE_FILE="../Vagrantfile"

dir="$(pwd)/$1"
mkdir -p "$dir"

ln -s "$VAGRANT_ANSIBLE_FILE"  "$dir/Vagrantfile" 2> /dev/null

cat > "$dir/vagrant-ansible-provision.conf.rb" << EOF
\$LAB="$1"
\$SETTINGS_FILE="../servers.yml"
EOF

