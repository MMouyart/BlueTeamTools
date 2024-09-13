Cape is a newer self-hosted sandbox solution based on cuckoo.
As stated by the documentation, the recommendation for host and guest are Ubuntu 22.04 for host and windows 10 21H2 for guest.
For ease of use, clone the Cape github repo ```git clone https://github.com/kevoreilly/CAPEv2.git```, therefore, every mentionned script will be available on your system.

## Installing all dependencies
First dependencie to install is KVM. The documentation links to a script which automates the installation process.
Link to the script : https://github.com/kevoreilly/CAPEv2/blob/master/installer/kvm-qemu.sh#L37

In the script, every <WOOT> occurence should be replaced by real hardware pattern which can be found using the command acpidump. Alternatively you can replace all occurences with random characters.
```bash
wget https://raw.githubusercontent.com/kevoreilly/CAPEv2/master/installer/kvm-qemu.sh
sudo chmod a+x kvm-qemu.sh
sudo ./kvm-qemu.sh all | tee kvm-qemu.log
# if you face an error about needrestart, install the package
sudo apt-get install needrestart
```
If any error happens when trying to launch KVM or any of its related components, traceback the error and eventually reinstall manually the faulty component.

Cape installation can be made using the script that can be found there : https://github.com/kevoreilly/CAPEv2/blob/master/installer/cape2.sh
```bash
wget https://raw.githubusercontent.com/kevoreilly/CAPEv2/master/installer/cape2.sh
sudo chmod a+x cape2.sh
# if your current user is not cape
./cape2.sh base cape| tee cape.log
# if yout current user is cape
./cape2.sh base | tee cape.log
```

The scripts install various services :
- cape.service
- cape-processor.service
- cape-web.service
- cape-rooter.service

The script will enable all those services at boot.

If the scripts do not work properly, the best way to fix it is to cut the script and manually run it step by step (requires an understanding of the script).
If an error message appears regarding suricata and the suricata.service file that cannot be found on the system, do so :
```bash
cat >> /etc/systemd/system/suricata.service <<EOF
# Sample Suricata systemd unit file.
[Unit]
Description=Suricata Intrusion Detection Service
After=syslog.target network-online.target

[Service]
# Environment file to pick up $OPTIONS. On Fedora/EL this would be
# /etc/sysconfig/suricata, or on Debian/Ubuntu, /etc/default/suricata.
#EnvironmentFile=-/etc/sysconfig/suricata
#EnvironmentFile=-/etc/default/suricata
ExecStartPre=/bin/rm -f /var/run/suricata.pid
ExecStart=/sbin/suricata -c /etc/suricata/suricata.yaml --pidfile /var/run/suricata.pid $OPTIONS
ExecReload=/bin/kill -USR2 $MAINPID

[Install]
WantedBy=multi-user.target
EOF
```
## Configuration
Cape has 6 main configuration files located under /opt/CAPEv2/conf :
- cuckoo.conf: for configuring general behavior and analysis options.
- auxiliary.conf: for enabling and configuring auxiliary modules.
- kvm.conf: for defining the options for your virtualization software (the file has the same name as the machinery module you choose in cuckoo.conf).
- memory.conf: Volatility configuration.
- processing.conf: for enabling and configuring processing modules.
- reporting.conf: for enabling or disabling report formats.
- routing.conf: for defining the routing of internet connection for the VMs.

The installer script will normally configure those files, but you may want to modify them.
In order to have cape working, at least cuckoo.conf, auxiliary.conf and kvm.conf must be edited to fir your system.
In cuckoo.conf do so : 
- machinery in [cuckoo]: this defines which Machinery module you want CAPE to use to interact with your analysis machines. The value must be the name of the module without extension.
- ip and port in [resultserver]: defines the local IP address and port that CAPE is going to use to bind the result server to. Make sure this matches the network configuration of your analysis machines, or they won’t be able to return the collected results. By default, the resultserver will listen on 0.0.0.0:8000, meaning that you can access it on the web via localhost.
- connection in [database]: defines how to connect to the internal database. You can use any DBMS supported by SQLAlchemy using a valid Database Urls syntax. The default value corresponds to the postgresql database with the user and password defined in cape2.sh.

For kvm.conf, you must create a section dedicated to each analysis vm you wish to use (by default it has a section for 1 vm, cuckoo1). 
By default this file contains 2 sections for the machines names cape1 and cuckoo1. Modify either one of those to fit your vm configurations.

## Creation of the guest a.k.a. the analysis vm
First you need to have an iso file of windows (or any linux distro if you wish to analyse linux based malwares). 
Then create the vm and install python3 on this vm.

For windows machine, it is  required to disable UAC, auto update or check for updates for any software installed.

To have the agent running at startup with required privieleges, in windows do so :
- open task scheduler
- create basic task (right pane), name it as you want
- set the trigger to 'When i logon'
- in Action, select 'Start a program' and select the path of agent.py
- click finish
- open the properties of this task and tick the 'Run with highest priveleges' box

Additionnaly for windows, you can use a debloat tool to uninstall various useless apps (https://github.com/W4RH4WK/Debloat-Windows-10 or https://www.getblackbird.net/).
Disable microsoft store by removing the environment variable '%USERPROFILE%\AppData\Local\Microsoft\WindowsApps' from the user PATH.
Disabling any other service (defender, update, firewall...) can be necessary as well. If the virus real-time protection kicks off and deletes the sample automatically, you can turn it off (https://www.tenforums.com/tutorials/3569-turn-off-real-time-protection-microsoft-defender-antivirus.html).

Now that everything is done, you can either use this pristine vm and clone it to create analysis vms that can be modified and then deleted, or take a snapshot of this vm to further rollback to it after analysis.

If you want to use a linux analysis vm, you should be using an ubuntu one.
Once the vm is created, install all dependencies and configure the agent to run as root at startup.
```bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install python3:i386 -y
sudo apt install python3-distutils -y
sudo apt install systemtap-runtime -y
curl -sSL https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python3 get-pip.py
python3 -m pip install pyinotify
python3 -m pip install Pillow       # optional
python3 -m pip install pyscreenshot # optional
python3 -m pip install pyautogui    # optional

sudo crontab -e
@reboot python3 <path to agent.py>

sudo ufw disable
sudo timedatectl set-ntp off

sudo tee /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "0";
APT::Periodic::Unattended-Upgrade "0";
EOF

sudo systemctl stop snapd.service && sudo systemctl mask snapd.service
```
