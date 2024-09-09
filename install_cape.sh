#!/bin/bash
set -ex
# By @doomedraven - https://twitter.com/D00m3dR4v3n
# Copyright (C) 2011-2023 doomedraven.
# See the file 'LICENSE.md' for copying permission.
# Huge thanks to: @NaxoneZ @kevoreilly @ENZOK @wmetcalf @ClaudioWayne
# Static values
# Where to place everything
# CAPE TcpDump will sniff this interface
NETWORK_IFACE=virbr1
# On which IP TOR should listen
IFACE_IP="192.168.1.1"
# Confiures default network interface ip route table
INTERNET_IFACE=$(ip route | grep '^default'|awk '{print $5}')
# DB password
PASSWD="SuperPuperSecret"
# Only in case if you using distributed CAPE And MongoDB sharding.
DIST_MASTER_IP="192.168.1.1"
USER="cape"
# https://nginx.org/en/linux_packages.html
nginx_version=1.25.3
prometheus_version=2.20.1
grafana_version=7.1.5
node_exporter_version=1.0.1
# if set to 1, enables snmpd and other various bits to support
# monitoring via LibreNMS
librenms_enable=0
# snmp v1/2c community string to use
snmp_community=ChangeMePublicRO
# value for agentaddress... see snmpd.conf(5)
# if blank the default will be used
snmp_agentaddress=""
snmp_location='Rack, Room, Building, City, Country [GPSX,Y]'
snmp_contact='Foo <foo@bar>'
clamav_enable=0
# enable IPMI sensor checking with LibreNMS
librenms_ipmi=0
# args to pass to /usr/lib/nagios/plugins/check_mongodb.py
librenms_mongo_args=''
# warn value for the clamav check
librenms_clamav_warn=2
# crit value for the clamav check
librenms_clamav_crit=3
# enable librenms support for mdadm
librenms_mdadm_enable=0
# requires lsi_mrdsnmpmain
# https://docs.librenms.org/Extensions/Applications/#megaraid
librenms_megaraid_enable=0
# disabling this will result in the web interface being disabled
MONGO_ENABLE=1
DIE_VERSION="3.09"
TOR_SOCKET_TIMEOUT="60"
# if a config file is present, read it in
if [ -f "./cape-config.sh" ]; then
	. ./cape-config.sh
fi

UBUNTU_VERSION=$(lsb_release -rs)
OS="$(uname -s)"
MAINTAINER="$(whoami)"_"$(hostname)"
ARCH="$(dpkg --print-architecture)"
echo "[+] Installing CAPEv2"
cd /opt || return
git clone https://github.com/kevoreilly/CAPEv2/
#chown -R root:${USER} /usr/var/malheur/
#chmod -R =rwX,g=rwX,o=X /usr/var/malheur/
# Adapting owner permissions to the ${USER} path folder
cd "/opt/CAPEv2/" || return
pip3 install poetry crudini
CRYPTOGRAPHY_DONT_BUILD_RUST=1 sudo -u ${USER} bash -c 'export PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring; poetry install'
sudo -u ${USER} bash -c 'export PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring; poetry run extra/libvirt_installer.sh'
#packages are needed for build options in extra/yara_installer.sh
apt-get install libjansson-dev libmagic1 libmagic-dev -y
sudo -u ${USER} bash -c 'poetry run extra/yara_installer.sh'
sudo rm -rf yara-python
sudo usermod -aG kvm ${USER}
sudo usermod -aG libvirt ${USER}

# copy *.conf.default to *.conf so we have all properly updated fields, as we can't ignore old configs in repository
for filename in conf/default/*.conf.default; do cp -vf "./$filename" "./$(echo "$filename" | sed -e 's/.default//g' | sed -e 's/default//g')";  done
sed -i "/connection =/cconnection = postgresql://${USER}:${PASSWD}@localhost:5432/${USER}" conf/cuckoo.conf
# sed -i "/tor/{n;s/enabled = no/enabled = yes/g}" conf/routing.conf
# sed -i "/memory_dump = off/cmemory_dump = on" conf/cuckoo.conf
# sed -i "/machinery =/cmachinery = kvm" conf/cuckoo.conf
sed -i "/interface =/cinterface = ${NETWORK_IFACE}" conf/auxiliary.conf
chown ${USER}:${USER} -R "/opt/CAPEv2/"
if [ "$MONGO_ENABLE" -ge 1 ]; then
	crudini --set conf/reporting.conf mongodb enabled yes
fi
if [ "$librenms_enable" -ge 1 ]; then
	crudini --set conf/reporting.conf litereport enabled yes
	crudini --set conf/reporting.conf runstatistics enabled yes
fi

python3 utils/community.py -waf -cr

# Configure direct internet connection
sudo echo "400 ${INTERNET_IFACE}" >> /etc/iproute2/rt_tables

if [ ! -f /etc/sudoers.d/cape ]; then
	cat >> /etc/sudoers.d/cape << EOF
Cmnd_Alias CAPE_SERVICES = /usr/bin/systemctl restart cape-rooter, /usr/bin/systemctl restart cape-processor, /usr/bin/systemctl restart cape, /usr/bin/systemctl restart cape-web, /usr/bin/systemctl restart cape-dist, /usr/bin/systemctl restart cape-fstab, /usr/bin/systemctl restart suricata, /usr/bin/systemctl restart guac-web, /usr/bin/systemctl restart guacd
${USER} ALL=(ALL) NOPASSWD:CAPE_SERVICES
EOF
fi
