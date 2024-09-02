As stated by the cuckoosandbox site, it is preferable to have a host (to run the software in) that is using GNU/Linux and has the python package installer (pip) installed (and python).
In this example we will use an ubuntu 16.04 LTS machine for our host with virtualbox as our virtualisation.
In this tutorial, we will be using a user called cuckoo to run the cuckoo sandbox app, therefore, if you wish not to create this cuckoo user and run cuckoo with your default user, make sure to do all related groups configuration and working directory properly.

## Requirements
As stated for the requirements, python is necessary as well as python libraries, to install it, use your distro's package manager to install python and the required libraries.
```bash
sudo apt-get install python python-pip python-dev libffi-dev libssl-dev
sudo apt-get install python-virtualenv python-setuptools
sudo apt-get install libjpeg-dev zlib1g-dev swig
# install mongodb for the web gui
sudo apt-get install mongodb
# install postgresql for cuckoo (separate from mongodb that is specific to the web gui)
sudo apt-get install postgresql libpq-dev
# install virtualbox
echo deb http://download.virtualbox.org/virtualbox/debian xenial contrib | sudo tee -a /etc/apt/sources.list.d/virtualbox.list
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
sudo apt-get update
sudo apt-get install virtualbox-5.2
# install tcpdump
sudo apt-get install tcpdump apparmor-utils
sudo apt-get install libcap2-bin
sudo aa-disable /usr/sbin/tcpdump
# modify privileges for the cuckoo user to be able to use tcpdump*
sudo groupadd pcap
sudo usermod -a -G pcap cuckoo
sudo chgrp pcap /usr/sbin/tcpdump
sudo setcap cap_net_raw,cap_net_admin=eip /usr/sbin/tcpdump
# install m2crypto
sudo apt-get install swig
sudo pip install m3crypto==0.24.0
# install guacd
sudo apt install libguac-client-rdp0 libguac-client-vnc0 libguac-client-ssh0 guacd
```

You may encounter file openning limits related errors (the system does not allow cuckoo to open the amount of files it wants), to fix it some modifications are required.
```bash
# edit /etc/security/limits.conf and add at the end 
*         hard     nofile   500000
*         soft     nofile   500000
root      hard     nofile   500000
root      soft     nofile   500000
# edit /etc/pam.d/common-session and add at the end
session required pam_limits.so
# edit /etc/sysctl.conf and add at the end
fs.file-max = 2097152
# verify limits
sudo sysctl -p
cat /proc/sys/fs/file-max 
ulimit -Hn 
ulimit -Sn 
```

## Installation
First it is required to create a user for cuckoo
```bash
sudo adduser cuckoo
sudo usermod -a -G libvirtd cuckoo
```

Install virtualenv and use it to install cuckoo and vmcloak.
```bash
sudo apt-get -y install virtualenv
virtualenv cuckoo-test
. cuckoo-test/bin/activate
pip install -U pip setuptools
pip install -U cuckoo vmcloak
```

## Guest installation and configuration
Once cuckoo has been installed on your machine, it is required to create guests (vms) that will run the analysis. Depending on the kind of sample you wish to analyse, the guest can be a windows box or a gnu/linux distro. For gnu/linux distros, the process is the same as the installation for the host machine.

We will go for a windows box.

Once the iso file for the windows box has been installed, mount the file to then create a vm that has sufficient resources.
```bash
mkdir /mnt/win7
sudo mount -o ro,loop <win7>.iso /mnt/win7
```
Install vmcloack to automate guest configuration 
```bash
. <cuckoo virtual env location>/<venv name>/bin/activate
pip install -U mvcloak```.

Remove any virtual net that has been created for your guest (created by the virtualisation software) and create another one for your guest using mvcloak ```vmcloak-<vnet name>```.

Create the vm with vmcloak ```vmcloak init --verbose --<os type> <vm name> --cpus <number of cores> --ramsize <number of ram>```
And clone the vm to always keep a nice and clean base vm ```vmcloak clone <base vm> <new clone vm>```
```bash
vmcloak init --verbose --win7x64 win7x64base --cpus 2 --ramsize 2048
vmcloak clone win7x64base win7x64cuckoo
## open virtualbox and proceed to install windows 7, afterwards vmcloak will be automatically configuring registry, services...
```

After that you can install any additionnal packages for your vm ```vmcloak install <vm name> <package name>``` (the packages can be listed using ```vmcloak list deps```).
E.g. ```vmcloak install win7x64cuckoo adobepdf pillow dotnet java flash vcredist vcredist.version=2015u3 wallpaper```.

## Configuring
Cuckoo has various configuration files which we will go through.

1st one is cuckoo.conf, all of the following options are the most important ones : 
- machinery in the [Cuckoo] section which defines which virtualisation software to use with cuckoo (is equal to the module like virtualbox, vmware, kvm).
- ip and port in the [resultserver] section which specify the local ip and port for cuckoo to bind the result server on. These values must match the analysis machines' network configuration.
- connection in the [database] section which specifies the database connection string to connect to the internal database, the form of this string is as follow dialect+driver://username:password@host:port/database where dialect is the name of the database software (sqlite, mysql, postgresql...), driver is the name of the dbapi to use for connection (if the default driver associated with the driver is not what is being used), username is the name of the user to interact with the database, password is the value of the password to connect to the database, host is the name of the database user, database is the name of the database ; an example : postgresql+pg8000://dbuser:kx%40jj5%2Fg@pghost10/appdb.

2nd one is auxiliary.conf which defines additionnal modules to run with the malware analysis (packet sniffer, proxying...).

3rd one is <machinery>.conf which defines how cuckoo interacts with the virtualisation software, where machinery is the name of the virtualisation software (virtualbox, kvm...).

4th one is memory.conf which is used for memory dump analysis (to use volatility enable volatility in processing.conf and enable memory_dump in cuckoo.conf).

5th one is processing.conf which defines what modules to run in cuckoo.

Last one is reporting.conf which defines how the reports should be generated.

If you wish to use per-analysis routing (i.e. route each analysis vm to a specific network point) use the cuckoo router utility. To run the router as user that is not cuckoo ```cuckoo router -g <user>```, to use it with virtualenv ```sudo ~/venv/bin/cuckoo router```. If your are running a linux distro, you should configure iproute2 to register each network interface.
