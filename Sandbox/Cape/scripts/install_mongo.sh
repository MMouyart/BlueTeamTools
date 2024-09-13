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
if [ "$MONGO_ENABLE" -ge 1 ]; then
	echo "[+] Installing MongoDB"
	# Mongo >=5 requires CPU AVX instruction support https://www.mongodb.com/docs/manual/administration/production-notes/#x86_64
if grep -q ' avx ' /proc/cpuinfo; then
MONGO_VERSION="7.0"
else
	echo "[-] Mongo >= 5 is not supported"
	MONGO_VERSION="4.4"
fi

sudo curl -fsSL "https://pgp.mongodb.com/server-${MONGO_VERSION}.asc" | sudo gpg --dearmor -o /etc/apt/keyrings/mongo.gpg --yes
echo "deb [signed-by=/etc/apt/keyrings/mongo.gpg arch=amd64] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/${MONGO_VERSION} multiverse" > /etc/apt/sources.list.d/mongodb.list

apt-get update 2>/dev/null
apt-get install libpcre3-dev numactl cron -y
apt-get install -y mongodb-org
pip3 install pymongo -U

apt-get install -y ntp
systemctl start ntp.service && sudo systemctl enable ntp.service

if ! grep -q -E '^kernel/mm/transparent_hugepage/enabled' /etc/sysfs.conf; then
	sudo apt-get install sysfsutils -y
	echo "kernel/mm/transparent_hugepage/enabled = never" >> /etc/sysfs.conf
	echo "kernel/mm/transparent_hugepage/defrag = never" >> /etc/sysfs.conf
fi

if [ -f /lib/systemd/system/mongod.service ]; then
	systemctl stop mongod.service
	systemctl disable mongod.service
	rm /lib/systemd/system/mongod.service
	rm /lib/systemd/system/mongod.service
	systemctl daemon-reload
fi

if [ ! -f /lib/systemd/system/mongodb.service ]; then
	crontab -l | { cat; echo "@reboot /bin/mkdir -p /data/configdb && /bin/mkdir -p /data/db && /bin/chown mongodb:mongodb /data -R"; } | crontab -
	cat >> /lib/systemd/system/mongodb.service <<EOF
[Unit]
Description=High-performance, schema-free document-oriented database
Wants=network.target
After=network.target
[Service]
PermissionsStartOnly=true
#ExecStartPre=/bin/mkdir -p /data/{config,}db && /bin/chown mongodb:mongodb /data -R
# https://www.tutorialspoint.com/mongodb/mongodb_replication.htm
ExecStart=/usr/bin/numactl --interleave=all /usr/bin/mongod --setParameter "tcmallocReleaseRate=5.0"
# --replSet rs0
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
# enable on ramfs servers
# --wiredTigerCacheSizeGB=50
User=mongodb
Group=mongodb
# StandardOutput=syslog
# StandardError=syslog	
SyslogIdentifier=mongodb
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF
fi
sudo mkdir -p /data/{config,}db
sudo chown mongodb:mongodb /data/ -R
systemctl unmask mongodb.service
systemctl enable mongodb.service
systemctl restart mongodb.service

if ! crontab -l | grep -q -F 'delete-unused-file-data-in-mongo'; then
	crontab -l | { cat; echo "30 1 * * 0 cd /opt/CAPEv2 && sudo -u cape poetry run python ./utils/cleaners.py --delete-unused-file-data-in-mongo"; } | crontab -
fi

echo -n "https://www.percona.com/blog/2016/08/12/tuning-linux-for-mongodb/"
else
	echo "[+] Skipping MongoDB"
fi
