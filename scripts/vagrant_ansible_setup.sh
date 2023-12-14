# SIMPLE LIBVIRT INSTALLATION AND SETUP FOR DEBIAN DISTRIBUTION >= 11
# RUN AS ROOT.

SSH_KEY="${1}"

LIBVIRTD_USER="vagrant"
LIBVIRTD_MANAGEMENT_NETWORK_NAME="management_network"
LIBVIRTD_MANAGEMENT_BRIDGE_NAME="virbr1"
LIBVIRTD_MANAGEMENT_NETWORK_PREFIX="10.0.16."
LIBVIRTD_MANAGEMENT_NETWORK_MASK="255.255.255.0"
LIBVIRTD_MANAGEMENT_HOST_IP_SUFFIX="1"
LIBVIRTD_MANAGEMENT_HOST_IP_MAC="aa:aa:aa:8a:3c:01"
LIBVIRTD_MANAGEMENT_NETWORK_DHCP_START="${LIBVIRTD_MANAGEMENT_NETWORK_PREFIX}2"
LIBVIRTD_MANAGEMENT_NETWORK_DHCP_END="${LIBVIRTD_MANAGEMENT_NETWORK_PREFIX}254"

mkdir -p /root/.ssh && chmod 700 /root/.ssh

touch /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys

cat > test <<EOF
${SSH_KEY}
EOF

echo export LIBVIRT_DEFAULT_URI="qemu:///system" > /etc/environment
echo export VAGRANT_DEFAULT_PROVIDER=libvirt >> /etc/environment
echo export VAGRANT_EXPERIMENTAL="typed_triggers" >> /etc/environment

apt update --assume-yes
# Run commands as root
apt --assume-yes install vim uuid-runtime sipcalc

# Install libvirt
apt --assume-yes install --no-install-recommends qemu-system libvirt-clients libvirt-daemon-system
# Needed for vagrant image files
apt --assume-yes install --no-install-recommends qemu-utils

usermod -a -G libvirt ${LIBVIRTD_USER}
# Install dnsmasq
apt --assume-yes install --no-install-recommends dnsmasq

# Install resolvconf
apt --assume-yes install --no-install-recommends resolvconf

resolvconf -u

# Install vagrant and vagrant-libvirt
apt --assume-yes install --no-install-recommends vagrant-libvirt vagrant

mkdir -p /opt/virsh/networks/ && cd /opt/virsh/networks/
cat > ${OVS_BRIDGE_NAME}.xml <<EOF
<network connections='18'>
  <name>${OVS_BRIDGE_NAME}</name>
  <uuid>$(uuidgen)</uuid>
  <forward mode='bridge'/>
  <bridge name='${OVS_BRIDGE_NAME}'/>
  <virtualport type='openvswitch'/>
  <portgroup name='vlan-01' default='yes'>
  </portgroup>
  <portgroup name='vlan-101'>
    <vlan>
      <tag id='101'/>
    </vlan>
  </portgroup>
  <portgroup name='vlan-all'>
    <vlan trunk='yes'>
      <tag id='11'/>
      <tag id='101'/>
      <tag id='1001'/>
    </vlan>
  </portgroup>
</network>
EOF

cat > ${LIBVIRTD_MANAGEMENT_NETWORK_NAME}.xml <<EOF
<network ipv6='yes'>
  <name>${LIBVIRTD_MANAGEMENT_NETWORK_NAME}</name>
  <uuid>$(uuidgen)</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='${LIBVIRTD_MANAGEMENT_BRIDGE_NAME}' stp='on' delay='0'/>
  <mac address='${LIBVIRTD_MANAGEMENT_HOST_IP_MAC}'/>
  <ip address='${LIBVIRTD_MANAGEMENT_NETWORK_PREFIX}${LIBVIRTD_MANAGEMENT_HOST_IP_SUFFIX}' netmask='${LIBVIRTD_MANAGEMENT_NETWORK_MASK}'>
    <dhcp>
      <range start='${LIBVIRTD_MANAGEMENT_NETWORK_DHCP_START}' end='${LIBVIRTD_MANAGEMENT_NETWORK_DHCP_END}'/>
    </dhcp>
  </ip>
</network>
EOF

$(virsh net-list 2> /dev/null | grep -q "${LIBVIRTD_MANAGEMENT_NETWORK_NAME}") || virsh net-define ${LIBVIRTD_MANAGEMENT_NETWORK_NAME}.xml
virsh net-autostart ${LIBVIRTD_MANAGEMENT_NETWORK_NAME}
$(virsh net-list 2> /dev/null | grep -q "${LIBVIRTD_MANAGEMENT_NETWORK_NAME}") || virsh net-start ${LIBVIRTD_MANAGEMENT_NETWORK_NAME}