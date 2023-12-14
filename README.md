# Vagrant-ansible

### Prerequisites
- `vagrant` should be installed on the controller host
- vagrant-libvirt
- `ruby3` should be installed on the controller host
- A working libvirtd server

### Features
- Fast box creation with yaml configuration
- Create multiple vagrant lab environments using the same servers configuration file
- Multi-machine ansible provisioner deployment
- Run multiple vagrant provisioners
- Support assigning pseudostatic ip addresses for vagrant private and management networks through dhcp.

### How to use

#### Standalone

- Git clone or git fork this project
- Setup vagrant, libvirtd. There is an example on scripts/vagrant_ansible_setup.sh for debian system on how to do that.
- Copy servers.yml.dist to settings.yml
- Copy vagrant-ansible-provision.conf.rb.dist to vagrant-ansible-provision.conf.rb and configure it
- Run vagrant up

#### Run as a submodule
- Add this project as a submodule
- Run `git submodule init`'
- `cd vagrant-ansible && create_vagrant_ansible_env.sh`
- `cd ../vagrant`
- Configure your labs and servers configuration in ../vagrant folder
- Add multiple labs by running `create_vagrant_ansible_env.sh labname` in the vagrant folder
- Update with `git submodule update --recursive --remote`


All variables declared in `servers.yml` can be accessed by ansible variable ANSIBLE_EXTRA_VARS[inventory_hostname]['variable_name']
For example to access the variable `is_provisioned` which is set to true if the vm is already provisioned you can use `ANSIBLE_EXTRA_VARS[inventory_hostname]['is_provisioned']` from your ansible task.

Look in `servers.yml.sample` for examples of usage. Most of vagrant-libvirt configuration options can be changed in the `servers.yml` file.