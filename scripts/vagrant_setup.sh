#!/usr/bin/env bash

apt install --assume-yes \
  libvirt-dev \
  ruby-fog-libvirt

# Install vagrant and vagrant-libvirt
apt --assume-yes install --no-install-recommends vagrant

# Install latest version of vagrant-libvirt
vagrant plugin install vagrant-libvirt
