As stated by the cuckoosandbox site, it is preferable to have a host (to run the software in) that is using GNU/Linux and has the python package installer (pip) installed (and python).

## Requirements
As stated for the requirements, python is necessary as well as python libraries, to install it, use your distro's package manager to install python and the required libraries.
The following packages are required : 
- python
- python-pip
- python-dev
- libffi-dev
- libssl-dev
- python-virtualenv
- python-setuptools
- libjpeg-dev
- zlib1g-dev
- swig

To have a web-based interface mongodb is required (install it with your package manager).

To use PgSQL for the database (which is recommended) install postgresql and libpq-dev (using your package manager).

For virtualisation purposes, install kvm and the required kvm libraries
- qemu-kvm
- libvirt-bin
- bridge-utils
- python-libvirt

Other required packages are
- tcpdump : for security reasons, cuckoo has to have some privileges to run tcpdump, therefore the following is required
```bash
sudo groupadd pcap
sudo usermod -a -G pcap cuckoo
sudo chgrp pcap /usr/sbin/tcpdump
sudo setcap cap_net_raw,cap_net_admin=eip /usr/sbin/tcpdump
```
- m2crypto (requires swig to be installed prior to this package)
- gguacd (packages are libguac-client-rdp0 libguac-client-vnc0 libguac-client-ssh0 guacd)

## Installation
First it is required to create a user for cuckoo
```bash
sudo adduser cuckoo
sudo usermod -a -G libvirtd cuckoo
```

We can install cuckoo using pip (this installs directly onto the system without virtualenv, and is therefore not recommended)
```bash
sudo pip installl -U pip setuptools
sudo pip install -U cuckoo
```

It is highly recommended to use virtualenv to avoid messing around with python packages in the system.
```bash
virtualenv venv
./venv/bin/activate
pip install -U pip setuptools
pip install -U cuckoo
```

By default when running cuckoo, a working directory will be created in the home directory, therefore all cuckoo related files will be found under /home/cuckoo.

## Configuring
Cuckoo has various file which we will go through.

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

## Guest installation and configuration
Once cuckoo has been installed on your machine, it is required to create guests (vms) that will run the analysis. Depending on the kind of sample you wish to analyse, the guest can be a windows box or a gnu/linux distro. For gnu/linux distros, the process is the same as the installation for the host machine.

