# -*- mode: ruby -*-
# vi: set ft=ruby :

# Require YAML module
VAGRANTFILE_DIR = File.dirname(File.expand_path(__FILE__))

require 'yaml'
require 'nokogiri'
require 'ipaddr'
# This file points to the location of the vagrant settings file and which lab to load
require "#{VAGRANTFILE_DIR}/vagrant-ansible-provision.conf.rb"

# VAGRANT_LOG=info vagrant up
# VAGRANT_EXPERIMENTAL="typed_triggers"

def initializeLabServerList(lab)
  _server_list = SETTINGS['labs']["#{lab}"]['servers'].each
  _server_list.each do | server |

    _lab_settings = SETTINGS['labs']["#{lab}"]['lab_settings'] ? SETTINGS['labs']["#{lab}"]['lab_settings'] : {}
    _server = DEFAULT_GLOBAL_SETTINGS.merge(_lab_settings).merge(server)

    if _server[:environment_file_path]
      require File.absolute_path(_server[:environment_file_path], VAGRANTFILE_DIR)
    end
    SERVERS.append(_server)
  end
  return SERVERS.sort_by { |_srv| _srv.fetch(:server_index_weight, 0) }
end

def provisioned?(vm_name='default', provider='libvirt')
  File.exist?(".vagrant/machines/#{vm_name}/#{provider}/action_provision")
end

def sshCommand(hypervisor_name="localhost")
  if hypervisor_name == 'localhost'
    return ''
  end
  return "ssh #{HYPERVISORS[:"#{hypervisor_name}"][:hypervisor_user]}@#{HYPERVISORS[:"#{hypervisor_name}"][:hypervisor_host]}"
end

def getBridgeName(network_name, hypervisor_name="localhost")
    _xml = Nokogiri::XML(`#{getVirsh(hypervisor_name)} net-dumpxml #{network_name} 2> /dev/null`)
    _bridge = _xml.at_xpath('//bridge/@name')
  return _bridge
end

def getServerIp(network, ip_address_offset)
  network_prefix = IPAddr.new(network).to_s.chop
  return "#{network_prefix}#{ip_address_offset}"
end

def getDhcpHostConf(mac, hostname, ip)
    return "<host mac='#{mac}' name='#{hostname}' ip='#{ip}'>"
end

def checkNetworkNameExists(network_name, hypervisor_name="localhost")
  network_name_exists = `#{getVirsh(hypervisor_name)} net-info #{network_name} 2> /dev/null | grep "#{network_name}"`
  return network_name_exists != '' ? true : false
end

def isHypervisorLocalhost?(hypervisor_name)
  return hypervisor_name == 'localhost'
end

def getVirsh(hypervisor_name="localhost")
  if hypervisor_name == 'localhost'
    return "virsh --connect #{ENV['LIBVIRT_DEFAULT_URI']}"
  end
  return "virsh --connect qemu+ssh://#{HYPERVISORS[:"#{hypervisor_name}"][:hypervisor_user]}@#{HYPERVISORS[:"#{hypervisor_name}"][:hypervisor_host]}/system"
end

def add_dhcp_host_conf(network_name, network_address, network_mac, hostname, ip_address_offset, hypervisor_name="localhost")
  _cmd = ''
  _bridge_name = getBridgeName(network_name, hypervisor_name)
  _ip =  getServerIp(network_address, ip_address_offset)
  _dhcp_host_conf = getDhcpHostConf(network_mac, hostname, _ip)
  _cmd_dhcp_host_conf_check_exists = "(#{getVirsh(hypervisor_name)} net-dumpxml #{network_name} 2> /dev/null | grep \\\"#{_dhcp_host_conf}\\\" > /dev/null)"
  _cmd_dhcp_host_conf_add = "{ #{getVirsh(hypervisor_name)} net-update #{network_name} add ip-dhcp-host \\\"<host mac='#{network_mac}' name='#{hostname}' ip='#{_ip}'> <lease expiry='48' unit='hours' /> </host>\\\" --live --config --parent-index 0 2> /dev/null;"
  _cmd_dhcp_host_conf_add += "#{sshCommand(hypervisor_name)} sudo DNSMASQ_INTERFACE='#{_bridge_name}' DNSMASQ_SUPPLIED_HOSTNAME='#{hostname}' /usr/lib/libvirt/libvirt_leaseshelper add '#{network_mac}' '#{_ip}'; }"
  _cmd = "#{_cmd_dhcp_host_conf_check_exists} || #{_cmd_dhcp_host_conf_add};"
end

def del_dhcp_host_conf(network_name, network_address, network_mac, hostname, ip_address_offset, hypervisor_name="localhost")
  _cmd = ''
  _bridge_name = getBridgeName(network_name, hypervisor_name)
  _ip =  getServerIp(network_address, ip_address_offset)
  _dhcp_host_conf = getDhcpHostConf(network_mac, hostname, _ip)
  _cmd_dhcp_host_conf_check_exists = "!(#{getVirsh(hypervisor_name)} net-dumpxml #{network_name} 2> /dev/null | grep \\\"#{_dhcp_host_conf}\\\" > /dev/null)"
  _cmd_dhcp_host_conf_del = "{ #{getVirsh(hypervisor_name)} net-update #{network_name} delete ip-dhcp-host \\\"<host mac='#{network_mac}' name='#{hostname}' ip='#{_ip}'> <lease expiry='48' unit='hours' /> </host>\\\" --live --config --parent-index 0 2> /dev/null;"
  _cmd_dhcp_host_conf_del += "#{sshCommand(hypervisor_name)} sudo DNSMASQ_INTERFACE='#{_bridge_name}' DNSMASQ_SUPPLIED_HOSTNAME='#{hostname}' /usr/lib/libvirt/libvirt_leaseshelper del '#{network_mac}' '#{_ip}'; }"
  _cmd = "#{_cmd_dhcp_host_conf_check_exists} || #{_cmd_dhcp_host_conf_del};"
end

# Global variables

# These variables are load from vagrant-ansible-provision.conf.rb file.
SETTINGS_FILE = $SETTINGS_FILE
LAB = $LAB ? $LAB : "default"

if File.file?("#{SETTINGS_FILE}")
  SETTINGS = YAML.load_file("#{SETTINGS_FILE}", aliases: true)
else
  SETTINGS = YAML.load_file("#{VAGRANTFILE_DIR}/servers.yml.dist", aliases: true)
end

SYNCED_FOLDERS = SETTINGS.fetch('synced_folders', {})
PROVISIONERS = SETTINGS.fetch('provisioners', {})
HYPERVISORS = SETTINGS.fetch('hypervisors', {})
DEFAULT_GLOBAL_SETTINGS = SETTINGS['default_global_settings']
SERVERS = []
SERVERS = initializeLabServerList(LAB)
SERVERS_COUNT = SERVERS.length
SERVER_COUNTER = 0
ANSIBLE_MULTIMACHINE_SETTINGS = {}

Vagrant.configure("2") do |config|

  config.vagrant.plugins = "vagrant-libvirt"

  SERVERS.each do |_server|

    if _server[:disabled]
      SERVER_COUNTER +=1
      next
    end

    _management_network = _server.fetch(:management_network);

    config.vm.define _server[:hostname] do |worker|

      worker.trigger.before :up do |trigger|
        _cmd = ''
        trigger.on_error = :continue
        trigger.info = "Add DHCP host configuration for static management network IP"
        if _server[:mgmt_attach] and _management_network[:mac]
          _cmd += add_dhcp_host_conf(
            _management_network[:management_network_name],
            _management_network[:management_network_address],
            _management_network[:mac],
            _server[:hostname],
            _server[:ip_address_offset],
            _server[:hypervisor_name]
          )
        end
        _server[:private_networks].each do |net|
          if net[:type].eql? "dhcp" and net[:mac]
            _cmd += add_dhcp_host_conf(
              net[:libvirt__network_name],
              net[:libvirt__network_address],
              net[:mac],
              _server[:hostname],
              _server[:ip_address_offset],
              _server[:hypervisor_name]
            )
          end
        end
        unless _cmd.empty?
          trigger.run = {inline: "bash -c \"#{_cmd}\""}
        end
      end

      worker.trigger.after :"VagrantPlugins::ProviderLibvirt::Action::CreateNetworks", type: :action do |trigger|
        _cmd = ''
        trigger.on_error = :continue
        trigger.info = "Add DHCP host configuration for static ma      nagement network IP"

        if _server[:mgmt_attach] and _management_network[:mac]
          _cmd += add_dhcp_host_conf(
            _management_network[:management_network_name],
            _management_network[:management_network_address],
            _management_network[:mac],
            _server[:hostname],
            _server[:ip_address_offset],
            _server[:hypervisor_name]
          )
        end
        _server[:private_networks].each do |net|
          if net[:type].eql? "dhcp" and net[:mac]
            _cmd += add_dhcp_host_conf(
              net[:libvirt__network_name],
              net[:libvirt__network_address],
              net[:mac],
              _server[:hostname],
              _server[:ip_address_offset],
              _server[:hypervisor_name]
            )
          end
        end
        unless _cmd.empty?
          trigger.run = {inline: "bash -c \"#{_cmd}\""}
        end
      end

      # SYNCED FOLDERS

      _server[:synced_folders].each do |folder|
        _src = folder.is_a?(Hash) ? folder[:src] : SYNCED_FOLDERS[folder][:src];
        _dest = folder.is_a?(Hash) ? folder[:dest] : SYNCED_FOLDERS[folder][:dest];
        _options = folder.is_a?(Hash) ? folder[:options] : SYNCED_FOLDERS[folder][:options];
        worker.vm.synced_folder _src, _dest, **_options
      end

      worker.vm.box = _server[:box];
      if !_server[:box_url].nil?
        worker.vm.box_url = _server[:box_url];
      end

      worker.vm.hostname = _server[:hostname];

      # Network
      _server[:private_networks].each do |net|
        worker.vm.network :private_network, **net
      end

      _server[:public_networks].each do |net|
        worker.vm.network :public_network, **net
      end

      if !_server[:forwards].nil?
        _server[:forwards].each do |forward|
          worker.vm.network :forwarded_port, **forward
        end
      end

      worker.vm.provider :libvirt do |libvirt|

        # Libvirt hypervisor connection Option
        if !HYPERVISORS[:"#{_server[:hypervisor_name]}"][:uri].nil?
          libvirt.uri = HYPERVISORS[:"#{_server[:hypervisor_name]}"][:uri]
        else
          libvirt.host = HYPERVISORS[:"#{_server[:hypervisor_name]}"][:hypervisor_host]
          libvirt.username = HYPERVISORS[:"#{_server[:hypervisor_name]}"][:hypervisor_user]
          libvirt.password = HYPERVISORS[:"#{_server[:hypervisor_name]}"][:password]
          libvirt.id_ssh_key_file = HYPERVISORS[:"#{_server[:hypervisor_name]}"][:hypervisor_id_ssh_key_file]
          libvirt.connect_via_ssh = HYPERVISORS[:"#{_server[:hypervisor_name]}"][:hypervisor_connect_via_ssh]
        end
        libvirt.driver = "kvm"
        libvirt.proxy_command = HYPERVISORS[:"#{_server[:hypervisor_name]}"][:hypervisor_proxy_command]

        # Domain Specific Options
        libvirt.default_prefix = "#{LAB}_";
        libvirt.title = _server.fetch(:title, _server[:hostname])
        libvirt.description = _server.fetch(:description, _server[:hostname])
        libvirt.cpus = _server[:cpus].to_s;
        libvirt.memory = _server[:ram].to_s;
        libvirt.autostart = _server[:autostart].to_s == 'true' ?  true : false;
        libvirt.nested = _server[:nested].to_s == 'true' ?  true : false;
        libvirt.qemu_use_agent = _server[:qemu_use_agent].to_s == 'true' ? true : false;
        libvirt.mgmt_attach = _server[:mgmt_attach].to_s == 'false' ? false : true;

        if !_server[:cpuaffinitiy].nil?
          libvirt.cpuaffinitiy _server[:cpuaffinitiy];
        end

        if !_server[:cputopology].nil?
          libvirt.cputopology = _server[:cputopology].to_s;
        end

        if !_server[:cpuset].nil?
          libvirt.cpus = _server[:cpuset].to_s;
        end

        if !_server[:numa_nodes].nil?
          libvirt.numa_nodes = _server[:numa_nodes].to_s;
        end

        # Management Network
        if _server[:mgmt_attach]

          libvirt.management_network_name = _management_network[:management_network_name];
          libvirt.management_network_address = _management_network[:management_network_address];
          libvirt.management_network_iface_name = _management_network[:management_network_iface_name];
          libvirt.management_network_mtu = _management_network[:management_network_mtu] ? _management_network[:management_network_mtu] : '1500';
          libvirt.management_network_autostart = _management_network[:management_network_autostart].to_s == 'false' ? false : true;
          libvirt.management_network_keep = _management_network[:management_network_keep].to_s == 'false' ? false : true;
          libvirt.management_network_mode = _management_network[:management_network_mode] ? _management_network[:management_network_mode] : 'nat';
          libvirt.management_network_domain = _management_network[:management_network_domain] ? _management_network[:management_network_domain] : nil;
          libvirt.management_network_model_type = _management_network[:management_network_model_type] ? _management_network[:management_network_model_type] : 'virtio';
          if !_management_network[:mac].nil?
            libvirt.management_network_mac = _management_network[:mac];
          end
        end

        # Storage
        _server[:storage].each do |disk|
          libvirt.storage :file, disk;
        end
      end

      SERVER_COUNTER +=1

      _server[:provisioners].each do |provisioner|
        _provisioner = provisioner.is_a?(Hash) ? provisioner : PROVISIONERS[provisioner]
        _provisioner_options = _provisioner[:options]
        _provisioner_name = _provisioner[:name]
        _limit_set = _provisioner_options.fetch(:limit, [])

        if _provisioner_options[:type].eql?("ansible")
          _ansible_vagrant_configuration = {}
          _ansible_vagrant_configuration = {
            server: _server,
            management_network: _management_network,
            lab: LAB,
            synced_folders: SYNCED_FOLDERS,
            provisioners: PROVISIONERS,
            is_provisioned: false,
            vagrantfile_dir: VAGRANTFILE_DIR,
            environment_variables: $ENVIRONMENT_VARIABLES
          }

          if provisioned?(_server[:hostname])
            _ansible_vagrant_configuration[:is_provisioned] = true;
          end

          _custom_ansible_overrides = {
            limit: _server[:hostname],
            extra_vars:
              Vagrant::Util::DeepMerge.deep_merge(
                _provisioner_options.fetch(
                  :extra_vars,
                  _server.fetch(:ansible_extra_vars, {})
                  ),
                { 'ANSIBLE_EXTRA_VARS': _ansible_vagrant_configuration}
              )
          }
          _custom_ansible_defaults = {
            playbook: "#{_provisioner.fetch(:ansible_playbook_dir, _server.fetch(:ansible_playbook_dir, 'ansible'))}/#{_provisioner.fetch(:ansible_playbook , _server.fetch(:ansible_playbook, nil))}",
            playbook_command: _server.fetch(:ansible_playbook_command, "ansible-playbook"),
            verbose: _server[:ansible_verbose],
            become: _server[:ansible_become] ? true : false,
            become_user: _server[:ansible_become_user] ? _server[:ansible_become_user] : 'root',
            compatibility_mode: "2.0",
            raw_ssh_args: _server[:ansible_raw_ssh_args],
            start_at_task: _server[:ansible_start_at_task],
            tags: _server[:ansible_tags],
            skip_tags: _server[:ansible_skip_tags],
            inventory_path: _server[:ansible_inventory_path],
            host_vars: _server[:ansible_host_vars] ? _server[:ansible_host_vars] : {},
            groups: _server[:ansible_groups] ? _server[:ansible_groups] : {},
            config_file: _server[:ansible_config_file],
            vault_password_file: _server[:ansible_vault_password_file],
            force_remote_user: _server[:ansible_force_remote_user],
            raw_arguments: _server[:ansible_raw_arguments]
          }

          _provisioner_options = Vagrant::Util::DeepMerge.deep_merge(_custom_ansible_defaults, _provisioner_options)
          _provisioner_options = Vagrant::Util::DeepMerge.deep_merge(_provisioner_options, _custom_ansible_overrides)

          if not _provisioner[:ansible_serial_deployment]
            if not ANSIBLE_MULTIMACHINE_SETTINGS.key?(:"#{_provisioner_name}")
              ANSIBLE_MULTIMACHINE_SETTINGS[:"#{_provisioner_name}"] = {
                extra_vars: {},
                limit_hosts: [],
                provisioner: {},
                provisioner_options: {}
              }
            end

            ANSIBLE_MULTIMACHINE_SETTINGS[:"#{_provisioner_name}"][:extra_vars] = (_ansible_vagrant_configuration)

            if _limit_set.empty?
              ANSIBLE_MULTIMACHINE_SETTINGS[:"#{_provisioner_name}"][:limit_hosts].append(_server[:hostname])
            else
              ANSIBLE_MULTIMACHINE_SETTINGS[:"#{_provisioner_name}"][:limit_hosts] = _limit_set
            end

            ANSIBLE_MULTIMACHINE_SETTINGS[:"#{_provisioner_name}"][:provisioner] = Vagrant::Util::DeepMerge.deep_merge(
              ANSIBLE_MULTIMACHINE_SETTINGS[:"#{_provisioner_name}"][:provisioner],
              _provisioner
            )
            ANSIBLE_MULTIMACHINE_SETTINGS[:"#{_provisioner_name}"][:provisioner_options] =
              Vagrant::Util::DeepMerge.deep_merge(
                ANSIBLE_MULTIMACHINE_SETTINGS[:"#{_provisioner_name}"][:provisioner_options],
                _provisioner_options
            )

            if (SERVERS_COUNT == SERVER_COUNTER)
              next
            end

            _provisioner_options = {
              type: 'shell',
              inline: "echo Skipping provisioner #{_provisioner_name} ansible serial deployment for #{_server[:hostname]}"
            }

          end
        elsif _provisioner_options[:type].eql?("shell")
          _provisioner_options[:env] = $ENVIRONMENT_VARIABLES.merge(_provisioner_options.fetch(:env, {}))
        end
        worker.vm.provision _provisioner_name, **_provisioner_options
      end

      if (SERVERS_COUNT == SERVER_COUNTER)
        ANSIBLE_MULTIMACHINE_SETTINGS.keys.each do |provisioner_name|
          _provisioner = ANSIBLE_MULTIMACHINE_SETTINGS[:"#{provisioner_name}"][:provisioner]
          _provisioner_options = ANSIBLE_MULTIMACHINE_SETTINGS[:"#{provisioner_name}"][:provisioner_options]
          _provisioner_options[:limit] = ANSIBLE_MULTIMACHINE_SETTINGS[:"#{provisioner_name}"][:limit_hosts]

          if ANSIBLE_MULTIMACHINE_SETTINGS[:"#{provisioner_name}"][:limit_hosts].length != 0
            worker.vm.provision provisioner_name, **_provisioner_options
          end
        end
      end

      worker.trigger.after [:destroy] do |trigger|
        _cmd = ''
        trigger.on_error = :continue
        trigger.info = "Add DHCP host configuration for static management network IP"

        if _server[:mgmt_attach] and _management_network[:mac]
          _cmd = del_dhcp_host_conf(
            _management_network[:management_network_name],
            _management_network[:management_network_address],
            _management_network[:mac],
            _server[:hostname],
            _server[:ip_address_offset],
            _server[:hypervisor_name]
          )
        end

        _server[:private_networks].each do |net|
          if net[:type].eql? "dhcp" and net[:mac]
            _cmd += del_dhcp_host_conf(
              net[:libvirt__network_name],
              net[:libvirt__network_address],
              net[:mac],
              _server[:hostname],
              _server[:ip_address_offset],
              _server[:hypervisor_name]
            )
          end
        end

        unless _cmd.empty?
          trigger.run = {inline: "bash -c \"#{_cmd}\""}
        end
      end
    end
  end
end