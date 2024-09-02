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
connection = postgresql://cuckoo:<password>@localhost/cuckoo
## if you wish to connect your vms to internet find your current interface to enable forwarding with cuckoo vnets
sysctl -w net.ipv4.conf.<vnet name>.forwarding=1
sysctl -w net.ipv4.conf.<current interface name>.forwarding=1
sudo iptables -t nat -A POSTROUTING -o eth0 -s 192.168.56.0/24 -j MASQUERADE
sudo iptables -P FORWARD DROP
sudo iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -s 192.168.56.0/24 -j ACCEPT
## edit routing.conf to fit your netork configurations
## edit reporting.conf
## edit the line [mongodb] to be as follow
[mongodb]   enabled = yes

```

Now you use a terminal multiplexer like tmux to ease things.
1st start the router on a terminal session ```cuckoo rooter --sudo --group cuckoo```.
2nd make sure mongodb service is running (more on that later), start the web server ```cuckoo --cwd /tmp/cuckoo web --host 0.0.0.0 --port 8000```.
3rd start cuckoo on another terminal session ```cuckoo --debug```.

## Troubleshoot
If you encounter an issue with the web server stating it cannot connect to the mongodb database, 1st make sure the settings in reporting.conf are good (enable mongodb and make sure ip and ports are pointing correctly).
Then if everything is good so far, check that mongodb service is running ```systemctl status mongodb.service```.
If systemctl sees the service as running, try ```mongo | mongod``` and check the results, most likely these commands will bring you the issue.
Otherwise, check the logs ```cat /var/log/mongodb/mongodb.log```.
If you encounter a problem about missing /data/db folders, do as follow : 
```bash
mkdir /data/db
chmod -R u+rwx,g+rwx /data
chown -R mongodb:mongodb /data
systemctl restart mongodb.service
mongod
```
