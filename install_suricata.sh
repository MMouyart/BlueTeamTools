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

echo '[+] Installing Suricata'
add-apt-repository ppa:oisf/suricata-stable -y
apt-get install suricata -y
touch /etc/suricata/threshold.config

# Download etupdate to update Emerging Threats Open IDS rules:
pip3 install suricata-update
mkdir -p "/etc/suricata/rules"
if ! crontab -l | grep -q -F '15 * * * * /usr/bin/suricata-update'; then
	crontab -l | { cat; echo "15 * * * * /usr/bin/suricata-update --suricata /usr/bin/suricata --suricata-conf /etc/suricata/suricata.yaml -o /etc/suricata/rules/ && /usr/bin/suricatasc -c reload-rules /tmp/suricata-command.socket &>/dev/null"; } | crontab -
fi
if [ -d /usr/share/suricata/rules/ ]; then
	cp "/usr/share/suricata/rules/"* "/etc/suricata/rules/"
fi
if [ -d /var/lib/suricata/rules/ ]; then
	cp "/var/lib/suricata/rules/"* "/etc/suricata/rules/"
fi

# ToDo this is not the best solution but i don't have time now to investigate proper one
sed -i 's|CapabilityBoundingSet=CAP_NET_ADMIN|#CapabilityBoundingSet=CAP_NET_ADMIN|g' /lib/systemd/system/suricata.service
systemctl daemon-reload

#change suricata yaml
sed -i 's|#default-rule-path: /etc/suricata/rules|default-rule-path: /etc/suricata/rules|g' /etc/default/suricata
sed -i 's|default-rule-path: /var/lib/suricata/rules|default-rule-path: /etc/suricata/rules|g' /etc/suricata/suricata.yaml
sed -i 's/#rule-files:/rule-files:/g' /etc/suricata/suricata.yaml
sed -i 's/# - suricata.rules/ - suricata.rules/g' /etc/suricata/suricata.yaml
sed -i 's/RUN=yes/RUN=no/g' /etc/default/suricata
sed -i 's/mpm-algo: ac/mpm-algo: hs/g' /etc/suricata/suricata.yaml
sed -i 's/mpm-algo: auto/mpm-algo: hs/g' /etc/suricata/suricata.yaml
sed -i 's/#run-as:/run-as:/g' /etc/suricata/suricata.yaml
sed -i "s/#  user: suri/   user: ${USER}/g" /etc/suricata/suricata.yaml
sed -i "s/#  group: suri/   group: ${USER}/g" /etc/suricata/suricata.yaml
sed -i 's/depth: 1mb/depth: 0/g' /etc/suricata/suricata.yaml
sed -i 's/request-body-limit: 100kb/request-body-limit: 0/g' /etc/suricata/suricata.yaml
sed -i 's/response-body-limit: 100kb/response-body-limit: 0/g' /etc/suricata/suricata.yaml
sed -i 's/EXTERNAL_NET: "!$HOME_NET"/EXTERNAL_NET: "ANY"/g' /etc/suricata/suricata.yaml
sed -i 's|#pid-file: /var/run/suricata.pid|pid-file: /tmp/suricata.pid|g' /etc/suricata/suricata.yaml
sed -i 's|#ja3-fingerprints: auto|ja3-fingerprints: yes|g' /etc/suricata/suricata.yaml
#-k none
sed -i 's/#checksum-validation: none/checksum-validation: none/g' /etc/suricata/suricata.yaml
sed -i 's/checksum-checks: auto/checksum-checks: no/g' /etc/suricata/suricata.yaml

# https://forum.suricata.io/t/suricata-service-crashes-with-pthread-create-is-11-error-when-processing-pcap-with-capev2/3870/5
sed -i 's|limit-noproc: true|limit-noproc: false|g' /etc/suricata/suricata.yaml

# enable eve-log
python3 -c "pa = '/etc/suricata/suricata.yaml';q=open(pa, 'rb').read().replace(b'eve-log:\n  enabled: no\n', b'eve-log:\n  enabled: yes\n');open(pa, 'wb').write(q);"
python3 -c "pa = '/etc/suricata/suricata.yaml';q=open(pa, 'rb').read().replace(b'unix-command:\n  enabled: auto\n  #filename: custom.socket', b'unix-command:\n  enabled: yes\n  filename: /tmp/suricata-command.socket');open(pa, 'wb').write(q);"
# file-store
python3 -c "pa = '/etc/suricata/suricata.yaml';q=open(pa, 'rb').read().replace(b'file-store:\n  version: 2\n  enabled: no', b'file-store:\n  version: 2\n  enabled: yes');open(pa, 'wb').write(q);"

chown ${USER}:${USER} -R /etc/suricata
chown ${USER}:${USER} -R /var/log/suricata
systemctl restart suricata

