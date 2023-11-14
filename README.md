The intended usage of this project is to be used as a gitsubmodule.
Add it to your project like.

```bash
git submodule add https://github.com/nickpyrgio/vagrant-ansible.git

cd vagrant-ansible
./create_vagrant_ansible_env.sh
cd ../vagrant
# Edit your servers.yml with your setup
# If you want to use multiple labs optionally run
create_vagrant_ansible_env.sh labname
```

All variables declared in server.yml can be accessed by ansible variable ANSIBLE_EXTRA_VARS[inventory_hostname]['variable_name']
For example to access the variable `is_provisioned` which is set to true if the vm is already provisioned you can use `ANSIBLE_EXTRA_VARS[inventory_hostname]['is_provisioned']` from your ansible task


