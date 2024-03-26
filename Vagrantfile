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
    SERVERS.append(_server)
  end
  # We sort based on server_index_weight value.
  # By default servers will be configured based in the order defined.
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

def getHostIp(network_name, hypervisor_name="localhost")
  _xml = Nokogiri::XML(`#{getVirsh(hypervisor_name)} net-dumpxml #{network_name} 2> /dev/null`)
  _host_ip = _xml.at_xpath('//ip/@address')
  return _host_ip
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

def getVirsh(hypervisor_name="localhost")

  hypervisor = Hash(HYPERVISORS[:"#{hypervisor_name}"])

  if !hypervisor.fetch(:uri, nil).nil?
    virsh_connect = hypervisor[:uri]
  elsif hypervisor_name == 'localhost'
    virsh_connect = ENV['LIBVIRT_DEFAULT_URI']
  else
    virsh_connect = "virsh --connect qemu+ssh://#{hypervisor[:hypervisor_user]}@#{hypervisor[:hypervisor_host]}/system"
  end

  return "virsh --connect #{virsh_connect}"
end

def add_dhcp_host_conf(network_name, network_address, network_mac, hostname, ip_address_offset, hypervisor_name="localhost")
  _cmd = ''
  _hypervisor = Hash(HYPERVISORS[:"#{hypervisor_name}"])
  _leasehelper_path = _hypervisor.fetch(:leasehelper_path, "/usr/lib/libvirt/libvirt_leaseshelper")
  _bridge_name = getBridgeName(network_name, hypervisor_name)
  _ip =  getServerIp(network_address, ip_address_offset)
  _dhcp_host_conf = getDhcpHostConf(network_mac, hostname, _ip)
  _cmd_dhcp_host_conf_check_exists = "(#{getVirsh(hypervisor_name)} net-dumpxml #{network_name} 2> /dev/null | grep \\\"#{_dhcp_host_conf}\\\" > /dev/null)"
  _cmd_dhcp_host_conf_add = "{ #{getVirsh(hypervisor_name)} net-update #{network_name} add ip-dhcp-host \\\"<host mac='#{network_mac}' name='#{hostname}' ip='#{_ip}'> <lease expiry='48' unit='hours' /> </host>\\\" --live --config --parent-index 0 2> /dev/null;"
  _cmd_dhcp_host_conf_add += "#{sshCommand(hypervisor_name)} sudo DNSMASQ_INTERFACE='#{_bridge_name}' DNSMASQ_SUPPLIED_HOSTNAME='#{hostname}' #{_leasehelper_path} add '#{network_mac}' '#{_ip}'; }"
  _cmd = "#{_cmd_dhcp_host_conf_check_exists} || #{_cmd_dhcp_host_conf_add};"
end

def del_dhcp_host_conf(network_name, network_address, network_mac, hostname, ip_address_offset, hypervisor_name="localhost")
  _cmd = ''
  _hypervisor = Hash(HYPERVISORS[:"#{hypervisor_name}"])
  _leasehelper_path = _hypervisor.fetch(:leasehelper_path, "/usr/lib/libvirt/libvirt_leaseshelper")
  _bridge_name = getBridgeName(network_name, hypervisor_name)
  _ip =  getServerIp(network_address, ip_address_offset)
  _dhcp_host_conf = getDhcpHostConf(network_mac, hostname, _ip)
  _cmd_dhcp_host_conf_check_exists = "!(#{getVirsh(hypervisor_name)} net-dumpxml #{network_name} 2> /dev/null | grep \\\"#{_dhcp_host_conf}\\\" > /dev/null)"
  _cmd_dhcp_host_conf_del = "{ #{getVirsh(hypervisor_name)} net-update #{network_name} delete ip-dhcp-host \\\"<host mac='#{network_mac}' name='#{hostname}' ip='#{_ip}'> <lease expiry='48' unit='hours' /> </host>\\\" --live --config --parent-index 0 2> /dev/null;"
  _cmd_dhcp_host_conf_del += "#{sshCommand(hypervisor_name)} sudo DNSMASQ_INTERFACE='#{_bridge_name}' DNSMASQ_SUPPLIED_HOSTNAME='#{hostname}' #{_leasehelper_path} del '#{network_mac}' '#{_ip}'; }"
  _cmd = "#{_cmd_dhcp_host_conf_check_exists} || #{_cmd_dhcp_host_conf_del};"
end


Vagrant.configure("2") do |config|

  config.vagrant.plugins = [
    "vagrant-libvirt"
  ]

  # Global variables

  # These variables are loaded from vagrant-ansible-provision.conf.rb file.

  # Global servers settings file for all labs
  SETTINGS_FILE = $SETTINGS_FILE

  # If no lab is defined, the default lab is assumed
  LAB = $LAB ? $LAB : "default"

  ENVIRONMENT_FILE = $ENVIRONMENT_FILE
  VAGRANT_ANSIBLE_ENVIRONMENT = {}
  # Merge ENV into VAGRANT_ANSIBLE_ENVIRONMENT
  ENV.each_pair { |name, value| VAGRANT_ANSIBLE_ENVIRONMENT[name] = value } # => ENV

  if File.file?("#{ENVIRONMENT_FILE}")
    environment = YAML.load_file("#{ENVIRONMENT_FILE}", aliases: true)
    VAGRANT_ANSIBLE_ENVIRONMENT.merge!(environment)
  end

  YAML.add_domain_type("", "Env") do |type, value|
    VAGRANT_ANSIBLE_ENVIRONMENT[value]
  end

  YAML.add_domain_type("", "Json") do |type, value|
    "#{value.to_json}"
  end

  if File.file?("#{SETTINGS_FILE}")
    SETTINGS = YAML.load_file("#{SETTINGS_FILE}", aliases: true)
  else
    SETTINGS = YAML.load_file("#{VAGRANTFILE_DIR}/servers.yml.dist", aliases: true)
  end

  SYNCED_FOLDERS = SETTINGS.fetch('synced_folder_definitions', {})
  PROVISIONERS = SETTINGS.fetch('provisioner_definitions', {})
  HYPERVISORS = SETTINGS.fetch('hypervisor_definitions', {})
  DEFAULT_GLOBAL_SETTINGS = SETTINGS['default_global_settings']
  SERVERS = []
  SERVERS = initializeLabServerList(LAB)
  SERVERS_COUNT = SERVERS.length
  SERVER_COUNTER = 0
  ANSIBLE_MULTIMACHINE_PROVISIONER_SETTINGS = {}
  ANSIBLE_EXTRA_VARS = {}

  SERVERS.each do |_server|

    if _server[:disabled]
      SERVER_COUNTER +=1
      next
    end

    _management_network = _server.fetch(:management_network);

    config.vm.define _server[:hostname],
      autostart: _server.fetch(:vagrant_autostart, true),
      primary: _server.fetch(:primary, false) do |worker|

      worker.trigger.before :up do |trigger|
        _cmd = ''
        trigger.on_error = :continue
        trigger.info = "Add DHCP host configuration for static management network IP"
        if _server[:mgmt_attach] and _management_network[:mac] and _server[:ip_address_offset]
          _cmd += add_dhcp_host_conf(
            _management_network[:management_network_name],
            _management_network[:management_network_address],
            _management_network[:mac],
            _server[:hostname],
            _server[:ip_address_offset],
            _server.fetch(:hypervisor_name, "localhost")
          )
        end
        _server[:private_networks].each do |net|
          if net[:type].eql? "dhcp" and net[:mac] and _server[:ip_address_offset]
            _cmd += add_dhcp_host_conf(
              net[:libvirt__network_name],
              net[:libvirt__network_address],
              net[:mac],
              _server[:hostname],
              _server[:ip_address_offset],
              _server.fetch(:hypervisor_name, "localhost")
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
        trigger.info = "Add DHCP host configuration for static management network IP"

        if _server[:mgmt_attach] and _management_network[:mac] and _server[:ip_address_offset]
          _cmd += add_dhcp_host_conf(
            _management_network[:management_network_name],
            _management_network[:management_network_address],
            _management_network[:mac],
            _server[:hostname],
            _server[:ip_address_offset],
            _server.fetch(:hypervisor_name, "localhost")
          )
        end
        _server[:private_networks].each do |net|
          if net[:type].eql? "dhcp" and net[:mac] and _server[:ip_address_offset]
            _cmd += add_dhcp_host_conf(
              net[:libvirt__network_name],
              net[:libvirt__network_address],
              net[:mac],
              _server[:hostname],
              _server[:ip_address_offset],
              _server.fetch(:hypervisor_name, "localhost")
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

      # Box settings
      if _server[:box].is_a?(Hash)

        worker.vm.box = _server[:box][:box]
        if !_server[:box][:url].nil?
          worker.vm.box_url = _server[:box][:url]
        end
        if !_server[:box][:version].nil?
          worker.vm.box_version = _server[:box][:version]
        end
        if !_server[:box][:download_checksum].nil?
          worker.vm.box_download_checksum = _server[:box][:download_checksum]
        end
        if !_server[:box][:download_checksum_type].nil?
          worker.vm.box_download_checksum_type= _server[:box][:download_checksum_type]
        end
      else
        worker.vm.box = _server[:box]
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
        hypervisor = Hash(HYPERVISORS[:"#{_server.fetch(:hypervisor_name, "localhost")}"])

        if !hypervisor[:uri].nil?
          libvirt.uri = hypervisor[:uri]
        else
          libvirt.host = hypervisor[:hypervisor_host]
          libvirt.username = hypervisor[:hypervisor_user]
          libvirt.password = hypervisor[:password]
          libvirt.id_ssh_key_file = hypervisor[:hypervisor_id_ssh_key_file]
          libvirt.connect_via_ssh = hypervisor[:hypervisor_connect_via_ssh]
        end
        libvirt.driver = "kvm"
        libvirt.storage_pool_name = hypervisor.fetch(:storage_pool_name, 'default')
        libvirt.snapshot_pool_name = hypervisor.fetch(:snapshot_pool_name, 'default')

        if !hypervisor[:hypervisor_proxy_command].nil?
          libvirt.proxy_command = hypervisor.fetch(:hypervisor_proxy_command)
        end

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

        if !_server[:cpu_mode].nil?
          libvirt.cpu_mode = _server[:cpu_mode];
        end

        if !_server[:cpu_model].nil?
          libvirt.cpu_model = _server[:cpu_model];
        end

        if !_server[:cpu_fallback].nil?
          libvirt.cpu_fallback = _server[:cpu_fallback];
        end

        if !_server[:cpuaffinitiy].nil?
          libvirt.cpuaffinitiy _server[:cpuaffinitiy];
        end

        if !_server[:cputopology].nil?
          libvirt.cputopology _server[:cputopology] ;
        end

        if !_server[:cpuset].nil?
          libvirt.cpuset = _server[:cpuset].to_s;
        end

        if !_server[:numa_nodes].nil?
          libvirt.numa_nodes = _server[:numa_nodes];
        end
        # boot order
        if !_server[:boot_order].nil?
          _server[:boot_order].each do |boot|
            libvirt.boot boot
          end
        end

        if !_server[:loader].nil?
          libvirt.loader = _server[:loader].to_s;
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

          _vagrant_server_configuration = {
            server: _server,
            management_network: _management_network,
            lab: LAB,
            synced_folders: SYNCED_FOLDERS,
            provisioners: PROVISIONERS,
            is_provisioned: false,
            vagrantfile_dir: VAGRANTFILE_DIR
          }

          if provisioned?(_server[:hostname])
            _vagrant_server_configuration[:is_provisioned] = true;
          end

          ANSIBLE_EXTRA_VARS.merge!("#{_server[:hostname]}": _vagrant_server_configuration)

          _custom_ansible_overrides = {
            limit: _server[:hostname],
            extra_vars:
              Vagrant::Util::DeepMerge.deep_merge(
                _provisioner_options.fetch(
                  :extra_vars,
                  _server.fetch(:ansible_extra_vars, {})
                  ),
                { 'ANSIBLE_EXTRA_VARS': ANSIBLE_EXTRA_VARS}
              )
          }
          _playbook = "#{_provisioner.fetch(:ansible_playbook , _server.fetch(:ansible_playbook, nil))}"

          if !_playbook.nil?
            _playbook = "#{_provisioner.fetch(:ansible_playbook_dir, _server.fetch(:ansible_playbook_dir, 'ansible'))}/#{_playbook}"
          end
          _custom_ansible_defaults = {
            playbook: "#{_playbook}",
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

          if (_provisioner_options.fetch(:playbook, nil).nil?) or !File.file?(_provisioner_options.fetch(:playbook))
            next
          end

          if not _provisioner[:ansible_serial_deployment]
            if not ANSIBLE_MULTIMACHINE_PROVISIONER_SETTINGS.key?(:"#{_provisioner_name}")
              ANSIBLE_MULTIMACHINE_PROVISIONER_SETTINGS[:"#{_provisioner_name}"] = {
                extra_vars: {},
                limit_hosts: [],
                provisioner: {},
                provisioner_options: {}
              }
            end

            ANSIBLE_MULTIMACHINE_PROVISIONER_SETTINGS[:"#{_provisioner_name}"][:extra_vars] = (_vagrant_server_configuration)

            if _limit_set.empty?
              ANSIBLE_MULTIMACHINE_PROVISIONER_SETTINGS[:"#{_provisioner_name}"][:limit_hosts].append(_server[:hostname])
            else
              ANSIBLE_MULTIMACHINE_PROVISIONER_SETTINGS[:"#{_provisioner_name}"][:limit_hosts] = _limit_set
            end

            ANSIBLE_MULTIMACHINE_PROVISIONER_SETTINGS[:"#{_provisioner_name}"][:provisioner] = Vagrant::Util::DeepMerge.deep_merge(
              ANSIBLE_MULTIMACHINE_PROVISIONER_SETTINGS[:"#{_provisioner_name}"][:provisioner],
              _provisioner
            )
            ANSIBLE_MULTIMACHINE_PROVISIONER_SETTINGS[:"#{_provisioner_name}"][:provisioner_options] =
              Vagrant::Util::DeepMerge.deep_merge(
                ANSIBLE_MULTIMACHINE_PROVISIONER_SETTINGS[:"#{_provisioner_name}"][:provisioner_options],
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
        end
        worker.vm.provision _provisioner_name, **_provisioner_options
      end

      if !_server[:vagrant_ssh_config].nil?
        _ssh_config = Hash(_server[:vagrant_ssh_config])
        if provisioned?(_server[:hostname]) or _ssh_config.fetch(:configure_before_provision, false)
          worker.ssh.private_key_path = _ssh_config.fetch(:private_key_path, "#{VAGRANTFILE_DIR}/.vagrant/machines/#{_server[:hostname]}/libvirt/private_key")
          worker.ssh.username = _ssh_config.fetch(:username, "vagrant")
          worker.ssh.extra_args = _ssh_config.fetch(:extra_args, [])
          worker.ssh.host = _ssh_config.fetch(:host, nil)
          worker.ssh.port = _ssh_config.fetch(:port, 22)
          worker.ssh.insert_key = _ssh_config.fetch(:insert_key, true)
          worker.ssh.keys_only = _ssh_config.fetch(:keys_only, true)
          worker.ssh.password = _ssh_config.fetch(:password, nil)
          worker.ssh.forward_agent = _ssh_config.fetch(:forward_agent, false)
          worker.ssh.forward_env = _ssh_config.fetch(:forward_env, nil)
          worker.ssh.shell = _ssh_config.fetch(:shell, 'bash -l')
        end
      end

      if !_server[:vagrant_winrm_config].nil?
        _winrm_config = Hash(_server[:vagrant_winrm_config])
        if provisioned?(_server[:hostname]) or _winrm_config.fetch(:configure_before_provision, false)
          worker.winrm.username = _winrm_config.fetch(:username, "vagrant")
          worker.winrm.password = _winrm_config.fetch(:password, 'vagrant')
          worker.winrm.host = _winrm_config.fetch(:host, nil)
          worker.winrm.port = _winrm_config.fetch(:port, 5986)
          worker.winrm.guest_port = _winrm_config.fetch(:port, 5985)
          worker.winrm.transport = _winrm_config.fetch(:transport, ':negotiate')
          worker.winrm.basic_auth_only = _winrm_config.fetch(:basic_auth_only, false)
          worker.winrm.ssl_peer_verification = _winrm_config.fetch(:ssl_peer_verification, false)
        end
      end

      # Run ansible multi-machine provisioners when we reach the last server iteration
      if (SERVERS_COUNT == SERVER_COUNTER)
        ANSIBLE_MULTIMACHINE_PROVISIONER_SETTINGS.keys.each do |provisioner_name|
          _provisioner = ANSIBLE_MULTIMACHINE_PROVISIONER_SETTINGS[:"#{provisioner_name}"][:provisioner]
          _provisioner_options = ANSIBLE_MULTIMACHINE_PROVISIONER_SETTINGS[:"#{provisioner_name}"][:provisioner_options]
          _provisioner_options[:limit] = ANSIBLE_MULTIMACHINE_PROVISIONER_SETTINGS[:"#{provisioner_name}"][:limit_hosts]

          if ANSIBLE_MULTIMACHINE_PROVISIONER_SETTINGS[:"#{provisioner_name}"][:limit_hosts].length != 0
            worker.vm.provision provisioner_name, **_provisioner_options
          end
        end
      end

      worker.trigger.after [:destroy] do |trigger|
        _cmd = ''
        trigger.on_error = :continue
        trigger.info = "Remove DHCP host configuration for static management network IP"

        if _server[:mgmt_attach] and _management_network[:mac] and _server[:ip_address_offset]
          _cmd = del_dhcp_host_conf(
            _management_network[:management_network_name],
            _management_network[:management_network_address],
            _management_network[:mac],
            _server[:hostname],
            _server[:ip_address_offset],
            _server.fetch(:hypervisor_name, "localhost")
          )
        end

        _server[:private_networks].each do |net|
          if net[:type].eql? "dhcp" and net[:mac] and _server[:ip_address_offset]
            _cmd += del_dhcp_host_conf(
              net[:libvirt__network_name],
              net[:libvirt__network_address],
              net[:mac],
              _server[:hostname],
              _server[:ip_address_offset],
              _server.fetch(:hypervisor_name, "localhost")
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
