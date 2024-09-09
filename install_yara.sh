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
echo '[+] Checking for old YARA version to uninstall'
dpkg -l|grep "yara-v[0-9]\{1,2\}\.[0-9]\{1,2\}\.[0-9]\{1,2\}"|cut -d " " -f 3|sudo xargs dpkg --purge --force-all 2>/dev/null
echo '[+] Installing Yara'
apt-get install libtool libjansson-dev libmagic1 libmagic-dev jq autoconf libyara-dev -y
cd /tmp || return
yara_info=$(curl -s https://api.github.com/repos/VirusTotal/yara/releases/latest)
yara_version=$(echo "$yara_info" |jq .tag_name|sed "s/\"//g")
yara_repo_url=$(echo "$yara_info" | jq ".zipball_url" | sed "s/\"//g")
if [ ! -f "$yara_version" ]; then
	wget -q "$yara_repo_url"
	unzip -q "$yara_version"
	#wget "https://github.com/VirusTotal/yara/archive/v$yara_version.zip" && unzip "v$yara_version.zip"
fi
directory=$(ls | grep "VirusTotal-yara-*")
mkdir -p /tmp/yara_builded/DEBIAN
cd "$directory" || return
./bootstrap.sh
./configure --enable-cuckoo --enable-magic --enable-profiling
make -j"$(getconf _NPROCESSORS_ONLN)"
yara_version_only=$(echo $yara_version|cut -c 2-)
echo -e "Package: yara\nVersion: $yara_version_only\nArchitecture: $ARCH\nMaintainer: $MAINTAINER\nDescription: yara-$yara_version" > /tmp/yara_builded/DEBIAN/control
make -j"$(nproc)" install DESTDIR=/tmp/yara_builded
dpkg-deb --build --root-owner-group /tmp/yara_builded
dpkg -i --force-overwrite /tmp/yara_builded.deb
#checkinstall -D --pkgname="yara-$yara_version" --pkgversion="$yara_version_only" --default
ldconfig
cd /tmp || return
git clone --recursive https://github.com/VirusTotal/yara-python
cd yara-python
# checkout tag v4.2.3 to work around broken master branch
# git checkout tags/v4.2.3
# sometimes it requires to have a copy of YARA inside of yara-python for proper compilation
# git clone --recursive https://github.com/VirusTotal/yara
# Temp workarond to fix issues compiling yara-python https://github.com/VirusTotal/yara-python/issues/212
# partially applying PR https://github.com/VirusTotal/yara-python/pull/210/files
# sed -i "191 i \ \ \ \ # Needed to build tlsh'\nmodule.define_macros.extend([('BUCKETS_128', 1), ('CHECKSUM_1B', 1)])\n# Needed to build authenticode parser\nmodule.libraries.append('ssl')" setup.py
python3 setup.py build --enable-cuckoo --enable-magic --enable-profiling
cd ..
# for root
pip3 install ./yara-python
if [ -d yara-python ]; then
	sudo rm -rf yara-python
fi
if id "cape" >/dev/null 2>&1; then
	cd /opt/CAPEv2/
	sudo -u cape poetry run extra/yara_installer.sh
	cd -
fi
if [ -d yara-python ]; then
	sudo rm -rf yara-python
fi
