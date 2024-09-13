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
cp /opt/CAPEv2/systemd/cape.service /lib/systemd/system/cape.service
cp /opt/CAPEv2/systemd/cape-processor.service /lib/systemd/system/cape-processor.service
cp /opt/CAPEv2/systemd/cape-web.service /lib/systemd/system/cape-web.service
cp /opt/CAPEv2/systemd/cape-rooter.service /lib/systemd/system/cape-rooter.service
cp /opt/CAPEv2/systemd/suricata.service /lib/systemd/system/suricata.service
systemctl daemon-reload
cape_web_enable_string=''
if [ "$MONGO_ENABLE" -ge 1 ]; then
	cape_web_enable_string="cape-web"
fi
systemctl enable cape cape-rooter cape-processor "$cape_web_enable_string" suricata
systemctl restart cape cape-rooter cape-processor "$cape_web_enable_string" suricata

