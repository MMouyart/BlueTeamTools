Cape is a newer self-hosted sandbox solution based on cuckoo.
As stated by the documentation, the recommendation for host and guest are Ubuntu for host and windows 7 for guest.
For ease of use, clone the Cape github repo (https://github.com/kevoreilly/CAPEv2.git), therefore, every mentionned script will be available on your system.

## Installing all dependencies
First dependencie to install is KVM. The documentation links to a script which automates the installation process.
Link to the script : https://github.com/kevoreilly/CAPEv2/blob/master/installer/kvm-qemu.sh#L37

In the script, every <WOOT> occurence should be replaced by real haardware pattern which can be found using the command acpidump.
```bash
sudo chmod a+x kvm-qemu.sh
sudo ./kvm-qemu.sh all | tee kvm-qemu.log
```
If any error happens when trying to launch KVM or any of its related components, traceback the error and eventually reinstall manually the faulty component.

Cape installation can be made using the script that can be found there : https://github.com/kevoreilly/CAPEv2/blob/master/installer/cape2.sh
```bash
sudo chmod a+x cape2.sh
./cape2.sh base cape | tee cape.log
```

The scripts install various services :
- cape.service
- cape-processor.service
- cape-web.service
- cape-rooter.service

To enable any service at boot use ```systemctl enable <service>```, to start them use ```systemctl start <service>```.

Cape has further dependencies which can either be installed using pip (using requirements.txt that can be found there : https://github.com/kevoreilly/CAPEv2/blob/master/requirements.txt

The recommended way is to use poetry for that.
```bash
## go to /opt/CAPEv2
poetry install
## confirm the creation of a virtual environment
poetry env list
## ouptput should look like this
capev2-t2x27zRb-py3.10 (Activated)
## now everytime you use cape, you should do so in the virtual environment
sudo -u cape poetry run <command>
```

Note that only the installation scripts and some utilities like the rooter must be executed with sudo, otherwise the rest must be executed under the cape user.

## Configuration
Cape has 6 main configuration files :
- cuckoo.conf: for configuring general behavior and analysis options.
- auxiliary.conf: for enabling and configuring auxiliary modules.
- kvm.conf: for defining the options for your virtualization software (the file has the same name as the machinery module you choose in cuckoo.conf).
- memory.conf: Volatility configuration.
- processing.conf: for enabling and configuring processing modules.
- reporting.conf: for enabling or disabling report formats.
- routing.conf: for defining the routing of internet connection for the VMs.

In order to have cape working, at least cuckoo.conf, auxiliary.conf and kvm.conf must be edited to fir your system.
In cuckoo.conf do so : 
- machinery in [cuckoo]: this defines which Machinery module you want CAPE to use to interact with your analysis machines. The value must be the name of the module without extension.
- ip and port in [resultserver]: defines the local IP address and port that CAPE is going to use to bind the result server to. Make sure this matches the network configuration of your analysis machines, or they won’t be able to return the collected results.
- connection in [database]: defines how to connect to the internal database. You can use any DBMS supported by SQLAlchemy using a valid Database Urls syntax.

For auxiliary.conf, you can see the default conf file and modify it to add additionnal modules.

For kvm.conf, you must create a section dedicated to each analysis vm you wish to use (by default it has a section for 1 vm, cuckoo1). See the default conf file : https://github.com/kevoreilly/CAPEv2/blob/master/conf/default/kvm.conf.default

To enable routing from your analysis vms, routing must be configured.
```bash
## configure ip forwarding
echo 1 | sudo tee -a /proc/sys/net/ipv4/ip_forward
sudo syctl -w net.ipv4.ip_forward=1
## enable networkd
sudo systemctl stop NetworkManager
sudo systemctl disable NetworkManager
sudo systemctl mask NetworkManager
sudo systemctl unmask systemd-networkd
sudo systemctl enable systemd-networkd
sudo systemctl start systemd-networkd
```
Next step is to configure netplan (and save it under/etc/netplan/99-manual.yaml).
In this configuration file you must specify each interface and the routes they should use.
```yaml
network:
    version: 2
    renderer: networkd
    ethernets:
        lo:
            addresses: [ "127.0.0.1/8", "::1/128", "7.7.7.7/32" ]
        enx00a0c6000000:
            dhcp4: no
            addresses: [ "192.168.1.2/24" ]
            nameservers:
                addresses: [ "192.168.1.1" ]
            routes:
                - to: default
                  via: 192.168.1.1
                - to: 192.168.1.0/24
                  via: 192.168.1.1
                  table: 101
            routing-policy:
             - from: 192.168.1.0/24
               table: 101
```

Apply the changes and check they are effective.
```bash
sudo netplan apply
## check the changes are effective
ip r show table all
```

The network must be configured to avoid having all ports open.
1st step is to allow access to administrative services (i.e. this machine).
```bash
# HTTP
sudo ufw allow in on enp8s0 to 10.23.6.66 port 80 proto tcp

# HTTPS
sudo ufw allow in on enp8s0 to 10.23.6.66 port 443 proto tcp

# SSH
sudo ufw allow in on enp8s0 to 10.23.6.66 port 22 proto tcp

# SMB (smbd is enabled by default on desktop versions of Ubuntu)
sudo ufw allow in on enp8s0 to 10.23.6.66 port 22 proto tcp

# RDP (if xrdp is used on the server)
sudo ufw allow in on enp8s0 to 10.23.6.66 port 445 proto tcp
```

Then allow the vm to access the cape result server.
```bash
sudo ufw allow in on virbr1 to 192.168.42.1 port 2042 proto tcp
sudo ufw enable
```

To manually test the internet conection from your vms.
```bash
sudo systemctl stop cape-rooter.service
sudo python3 router_manager.py -r internet -e --vm-name <vm name> --verbose
sudo python3 router_manager.py -r internet -d --vm-name <vm name> --verbose
```

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

Now that everything is dine, you can either use this vm pristine and clone it to create analysis vms that can be modified and then deleted, or take a snapshot of this vm to further rollback to it after analysis.

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

