# -*- mode: ruby -*-
# vi: set ft=ruby :

# Require YAML module
require 'yaml'
require 'nokogiri'
require 'ipaddr'

require "./vagrant-ansible-provision.conf.rb"

# VAGRANT_LOG=info vagrant up
# VAGRANT_EXPERIMENTAL="typed_triggers"

def initializeLabServerList(lab)
  _server_list = SETTINGS['labs']["#{lab}"]['servers'].each
  _server_list.each do | server |
    _lab_settings = SETTINGS['labs']["#{lab}"]['lab_settings'] ? SETTINGS['labs']["#{lab}"]['lab_settings'] : {}
    _server = DEFAULT_GLOBAL_SETTINGS.merge(_lab_settings).merge(server)
    SERVERS.append(_server)
  end
  return SERVERS.sort_by { |_srv| _srv[:ansible_deploy_individually] ? 0 : 1 }
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
CURRENT_DIR = File.dirname(File.expand_path(__FILE__))
SETTINGS_FILE = $SETTINGS_FILE
LAB = $LAB ? $LAB : "default"

if File.file?("#{SETTINGS_FILE}")
  SETTINGS = YAML.load_file("#{SETTINGS_FILE}", aliases: true)
else
  SETTINGS = YAML.load_file("#{CURRENT_DIR}/servers.yml.dist", aliases: true)
end

HYPERVISORS = SETTINGS['hypervisors']
DEFAULT_GLOBAL_SETTINGS = SETTINGS['default_global_settings']
SERVERS = []
SERVERS = initializeLabServerList(LAB)
SERVERS_COUNT = SERVERS.length
SERVER_COUNTER = 0
ANSIBLE_EXTRA_VARS = {}
ANSIBLE_LIMIT_HOSTS = []

Vagrant.configure("2") do |config|

  SERVERS.each do |_server|

    _management_network = _server[:management_network] ? _server[:management_network] : '';

    if _server[:disabled]
      SERVER_COUNTER +=1
      next
    end

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
        if _cmd != ''
          trigger.run = {inline: "bash -c \"#{_cmd}\""}
        end
      end

      worker.trigger.after :"VagrantPlugins::ProviderLibvirt::Action::CreateNetworks", type: :action do |trigger|
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
        if _cmd != ''
          trigger.run = {inline: "bash -c \"#{_cmd}\""}
        end
      end

      worker.vm.synced_folder ".", "/vagrant", disabled: true

      worker.vm.box = _server[:box];
      if !_server[:box_url].nil?
        worker.vm.box_url = _server[:box_url];
      end
      worker.vm.hostname = _server[:hostname];

      # Network
      _server[:private_networks].each do |net|
        worker.vm.network :private_network,
          (net[:type] ? :type : '_skip') => net[:type],
          (net[:libvirt__network_name] ? :libvirt__network_name : '_skip') => net[:libvirt__network_name],
          (net[:libvirt__network_address] ? :libvirt__network_address : '_skip') => net[:libvirt__network_address],
          (net[:libvirt__netmask] ? :libvirt__netmask : '_skip') => net[:libvirt__netmask],
          (net[:libvirt__host_ip] ? :libvirt__host_ip : '_skip') => net[:libvirt__host_ip],
          (net[:libvirt__domain_name] ? :libvirt__domain_name : '_skip') => net[:libvirt__domain_name],
          (net[:libvirt__dhcp_enabled] ? :libvirt__dhcp_enabled : '_skip') => net[:libvirt__dhcp_enabled],
          (net[:libvirt__dhcp_start] ? :libvirt__dhcp_start : '_skip') => net[:libvirt__dhcp_start],
          (net[:libvirt__dhcp_stop] ? :libvirt__dhcp_stop : '_skip') => net[:libvirt__dhcp_stop],
          (net[:libvirt__dhcp_bootp_file] ? :libvirt__dhcp_bootp_file : '_skip') => net[:libvirt__dhcp_bootp_file],
          (net[:libvirt__dhcp_bootp_server] ? :libvirt__dhcp_bootp_server : '_skip') => net[:libvirt__dhcp_bootp_server],
          (net[:libvirt__tftp_root] ? :libvirt__tftp_root : '_skip') => net[:libvirt__tftp_root],
          (net[:libvirt__adapter] ? :libvirt__adapter : '_skip') => net[:libvirt__adapter],
          (net[:libvirt__forward_mode] ? :libvirt__forward_mode : '_skip') => net[:libvirt__forward_mode],
          (net[:libvirt__forward_device] ? :libvirt__forward_device : '_skip') => net[:libvirt__forward_device],
          (net[:libvirt__tunnel_type] ? :libvirt__tunnel_type : '_skip') => net[:libvirt__tunnel_type],
          (net[:libvirt__tunnel_port] ? :libvirt__tunnel_port : '_skip') => net[:libvirt__tunnel_port],
          (net[:libvirt__tunnel_local_port] ? :libvirt__tunnel_local_port : '_skip') => net[:libvirt__tunnel_local_port],
          (net[:libvirt__tunnel_local_ip] ? :libvirt__tunnel_local_ip : '_skip') => net[:libvirt__tunnel_local_ip],
          (net[:libvirt__guest_ipv6] ? :libvirt__guest_ipv6 : '_skip') => net[:libvirt__guest_ipv6],
          (net[:libvirt__ipv6_address] ? :libvirt__ipv6_address : '_skip') => net[:libvirt__ipv6_address],
          (net[:libvirt__ipv6_prefix] ? :libvirt__ipv6_prefix : '_skip') => net[:libvirt__ipv6_prefix],
          (net[:libvirt__iface_name] ? :libvirt__iface_name : '_skip') => net[:libvirt__iface_name],
          (net[:mac] ? :libvirt__mac : '_skip') => net[:mac],
          (net[:libvirt__mtu] ? :libvirt__mtu : '_skip') => net[:libvirt__mtu],
          (net[:libvirt__model_type] ? :libvirt__model_type : '_skip') => net[:libvirt__model_type],
          (net[:libvirt__driver_name] ? :libvirt__driver_name : '_skip') => net[:libvirt__driver_name],
          (net[:libvirt__driver_queues] ? :libvirt__driver_queues : '_skip') => net[:libvirt__driver_queues],
          (net[:autostart] ? :autostart : '_skip') => net[:autostart],
          (net[:libvirt__bus] ? :libvirt__bus : '_skip') => net[:libvirt__bus],
          (net[:libvirt__slot] ? :libvirt__slot : '_skip') => net[:libvirt__slot],
          (net[:libvirt__always_destroy] ? :libvirt__always_destroy : '_skip') => net[:libvirt__always_destroy]
        end

      _server[:public_networks].each do |net|
        worker.vm.network :public_network,
          (net[:dev] ? :dev : '_skip') => net[:dev],
          (net[:mode] ? :mode : '_skip') => net[:mode],
          (net[:mac] ? :mac : '_skip') => net[:mac],
          (net[:type] ? :type : '_skip') => net[:type],
          (net[:network_name] ? :network_name : '_skip') => net[:network_name],
          (net[:portgroup] ? :portgroup : '_skip') => net[:portgroup],
          (net[:ovs] ? :ovs : '_skip') => net[:ovs],
          (net[:trust_guest_rx_filters] ? :trust_guest_rx_filters : '_skip') => net[:trust_guest_rx_filters],
          (net[:libvirt__iface_name] ? :libvirt__iface_name : '_skip') => net[:libvirt__iface_name],
          (net[:libvirt__iface_name] ? :libvirt__iface_name : '_skip') => net[:libvirt__iface_name],
          (net[:libvirt__mtu] ? :libvirt__mtu : '_skip') => net[:libvirt__mtu],
          (net[:auto_config] ? :auto_config : '_skip') => net[:auto_config],
          (net[:host_device_exclude_prefixes] ? :host_device_exclude_prefixes : '_skip') => net[:host_device_exclude_prefixes]
        end

      if !_server[:forwards].nil?
        _server[:forwards].each do |forward|
          _host_ip = forward[:host_ip] ? forward[:host_ip] : "localhost";
          _gateway_ports = forward[:_gateway_ports].to_s == 'true' ? true : false;
          worker.vm.network :forwarded_port, guest: forward[:guest], host: forward[:host], host_ip: _host_ip, gateway_ports: _gateway_ports
        end
      end

      worker.vm.provider :libvirt do |libvirt|

        # Libvirt host
        libvirt.host = HYPERVISORS[:"#{_server[:hypervisor_name]}"][:hypervisor_host];
        libvirt.username = HYPERVISORS[:"#{_server[:hypervisor_name]}"][:hypervisor_user];
        libvirt.id_ssh_key_file = HYPERVISORS[:"#{_server[:hypervisor_name]}"][:hypervisor_id_ssh_key_file];
        libvirt.connect_via_ssh = HYPERVISORS[:"#{_server[:hypervisor_name]}"][:hypervisor_connect_via_ssh];
        libvirt.driver = "kvm"
        libvirt.default_prefix = "#{LAB}_";

        # Management Network
        libvirt.mgmt_attach = _server[:mgmt_attach].to_s == 'false' ? false : true;
        if _server[:mgmt_attach]

          libvirt.management_network_name = _management_network[:management_network_name];
          libvirt.management_network_address = _management_network[:management_network_address];
          libvirt.management_network_iface_name = _management_network[:management_network_iface_name];
          libvirt.management_network_mtu = _management_network[:management_network_mtu] ? _management_network[:management_network_mtu] : '1500';
          libvirt.management_network_autostart = _management_network[:management_network_autostart].to_s == 'false' ? false : true;
          libvirt.management_network_keep = _management_network[:management_network_keep].to_s == 'false' ? false : true;
          libvirt.management_network_mode = _management_network[:management_network_mode] ? _management_network[:management_network_mode] : 'nat';
          libvirt.management_network_domain = _management_network[:management_network_domain] ? _management_network[:management_network_domain] : nil;
          if !_management_network[:mac].nil?
            libvirt.management_network_mac = _management_network[:mac];
          end
        end

        # Storage
        _server[:storage].each do |disk|
          libvirt.storage :file, disk;
        end

        # Cpu
        libvirt.cpus = _server[:cpus].to_s;

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

        libvirt.autostart = _server[:autostart].to_s == 'true' ?  true : false;

        #Enable nested virtualization
        libvirt.nested = _server[:nested].to_s == 'true' ?  true : false;

        # Memory
        libvirt.memory = _server[:ram].to_s;

        # Qemu agent
        libvirt.qemu_use_agent = _server[:qemu_use_agent].to_s == 'true' ? true : false;
      end

      if !_server[:ansible_playbook].nil?
        _ansible_inventory_vars = {
          server: _server,
          management_network: _management_network,
          lab: LAB,
          is_provisioned: false
        }

        if provisioned?(_server[:hostname])
          _ansible_inventory_vars[:is_provisioned] = true;
        end

        ANSIBLE_EXTRA_VARS.merge!("#{_server[:hostname]}": _ansible_inventory_vars)
        if not _server[:ansible_deploy_individually]
          ANSIBLE_LIMIT_HOSTS.append(_server[:hostname])
        end

        SERVER_COUNTER +=1

        if SERVERS_COUNT == SERVER_COUNTER or _server[:ansible_deploy_individually]
          if ANSIBLE_LIMIT_HOSTS.length != 0 or _server[:ansible_deploy_individually]
            worker.vm.provision "ansible" do |ansible|
              ansible.playbook = "#{_server[:ansible_playbook_dir]}/#{_server[:ansible_playbook]}"
              ansible.playbook_command = _server[:ansible_playbook_command] ? _server[:ansible_playbook_command] : "ansible-playbook"
              ansible.verbose = _server[:ansible_verbose]
              ansible.become = _server[:ansible_become] ? true : false;
              ansible.become_user = _server[:ansible_become_user] ? _server[:ansible_become_user] : 'root';
              ansible.compatibility_mode = "2.0"
              ansible.limit = _server[:ansible_deploy_individually] ? _server[:hostname] : ANSIBLE_LIMIT_HOSTS.join(',');
              # ansible.limit = "all"
              ansible.extra_vars = _server[:ansible_extra_vars].merge({ 'ANSIBLE_EXTRA_VARS': ANSIBLE_EXTRA_VARS })
              ansible.raw_ssh_args = _server[:ansible_raw_ssh_args]
              ansible.start_at_task = _server[:ansible_start_at_task]
              ansible.tags = _server[:ansible_tags]
              ansible.skip_tags = _server[:ansible_skip_tags]
              ansible.inventory_path = _server[:ansible_inventory_path]
              ansible.host_vars = _server[:ansible_host_vars] ? _server[:ansible_host_vars] : {}
              ansible.groups = _server[:ansible_groups] ? _server[:ansible_groups] : {}
              ansible.config_file = _server[:ansible_config_file]
              ansible.vault_password_file = _server[:ansible_vault_password_file]
              ansible.force_remote_user = _server[:ansible_force_remote_user]
              ansible.raw_arguments = _server[:ansible_raw_arguments]
            end
          end
        end
      end


      worker.trigger.after [:destroy] do |trigger|
        trigger.on_error = :continue
        trigger.info = "Add DHCP host configuration for static management network IP"

        if _server[:mgmt_attach]
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
          if net[:type].eql? "dhcp"
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

        if _cmd != ''
          trigger.run = {inline: "bash -c \"#{_cmd}\""}
        end
      end

    end
    #end config
  end
end