After the installation of cuckoo is done, it can now be used, but some configuration are required as well, which we will go through.
```bash
cuckoo init
cuckoo community
while read -r vm ip; do cuckoo machinie --add $vm $ip; done << (vmcloak list vms)
## edit virtualbox.conf
## remove cuckoo1 in the line machines =
## Create required user and database for pgsql
sudo -u postgres psql
CREATE DATABASE cuckoo;
CREATE USER cuckoo WITH ENCRYPTED PASSWORD '<password>';
GRANT ALL PRIVILEGES ON DATABASE cuckoo to cuckoo;
\q
## edit cuckoo.conf
## in the [database section] edit line connection to be
connection = postgresql://cuckoo:<password>@loaclhost/cuckoo
## if you wish to connect your vms to internet find your current interface to enable forwarding with cuckoo vnets
sysctl -w net.ipv4.conf.<vnet name>.forwarding=1
sysctl -w net.ipv4.conf.<current interface name>.forwarding=1
## edit routing.conf to fit your netork configurations
## edit reporting.conf
## edit the line [mongodb] to be as follow
[mongodb]   enabled = yes
## to start the web gui
cuckoo web -host 127.0.0.1 - port 8080
## go to localhost:8080 to acces the web gui
```

Now cuckoo sandbox is ready to be used.
