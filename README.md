# Ceph cluster deployment on Grid'5000

With this experiment, you can easily deploy a Ceph cluster on 8 nodes (32 OSDs), linked with a 10Gb/s network, for a final amount of 17TB of storage.

The goal of this experiment is to benchmark a Ceph cluster on Grid'5000 and compare the usage of `ext4` and `xfs` on OSDs, usage of a dedicated private network for replication, etc...

## Setup

### For usage from Grid'5000

#### Configure your environment

```shell
export PATH=~/.gem/ruby/1.9.1/bin:$PATH
export http_proxy=http://proxy:3128
export https_proxy=http://proxy:3128
```

#### Clone the repository

From a Grid'5000 frontend, here `frontend.rennes.grid5000.fr`.

```shell
git clone https://github.com/pmorillon/grid5000-xp-ceph.git
cd grid5000-xp-ceph
```

#### Install Rugygems dependencies with Bundler

```shell
gem install --user bundler
bundle install --path ~/.gem
```

#### Configure Restfully

```shell
mkdir -p ~/.restfully && echo '
uri: https://api.grid5000.fr/3.0/' > ~/.restfully/api.grid5000.fr.yml && chmod 600 ~/.restfully/api.grid5000.fr.yml
```

#### Configure XP5K

Create the file `xp.conf` into the `grid5000-xp-ceph` directory.

```
# OAR jobs defaults
walltime        '2:00:00'

# SSH configuration
public_key      File.expand_path '~/.ssh/id_rsa.pub'

# Choose a scenario (see ./scenarios directory)
scenario        'paranoia_4nodes_16osds_ext4'
```

### For external usage

#### Clone the repository

You can work from your workstation without to connect onto a Grid'5000 frontend.

```shell
git clone git@github.com:pmorillon/grid5000-xp-ceph.git
cd grid5000-xp-ceph
```

#### Install Rugygems dependencies with Bundler

Assuming that you use [RVM](https://rvm.io/) (Ruby Version Manager) :

```shell
bundle install
```

#### Configure Restfully

Configure [Restfully for an external access](https://api.grid5000.fr/doc/3.0/tools/restfully.html#how-do-i-avoid-passing-my-password-each-time-i-want-to-use-restfully).

#### Configure XP5K

Create the file `xp.conf` into the `grid5000-xp-ceph` directory.

```
# OAR jobs defaults
walltime        '2:00:00'

# Your Grid'5000 login
user            'mylogin'

# SSH configuration
public_key      File.expand_path '~/.ssh/id_rsa_g5k_external.pub'
gateway         "#{self[:user]}@frontend.rennes.grid5000.fr"
ssh_config      File.expand_path '~/.ssh/config_xp5k'

# Choose a scenario (see ./scenarios directory)
scenario        'paranoia_4nodes_16osds_ext4'
```


#### Configure ssh config file

[https://www.grid5000.fr/mediawiki/index.php/Xp5k#SSH](https://www.grid5000.fr/mediawiki/index.php/Xp5k#SSH)

## Usage

### Define a scenario

#### One site deployment

Here we use the default scenario described in the file `scenarios/paranoia_4nodes_16osds_ext4.yaml`.

```yaml
---
filesystem: ext4
site: rennes
frontend: true
compute: 1
cluster_network_interface: false
clusters:
  - name: 'paranoia'
  ceph_nodes_count: 4
  node_description:
    mon: sda
    osd:
      - sdb
      - sdc
      - sdd
      - sde
```

* `filesystem:` ext4 | xfs
* `site:` one of the Grid'5000 sites
* `frontend:` Install or node the frontend on the site, true or false (need at least one)
* `computes:` Number of computes nodes to deploy on the site
* `cluster_network_interface:` false | ethx (on this cluster we can use eth2, this will create a private network in a local vlan and configure OSDs with the proper _cluster addr_ attribute) (__Warning__ : Only available for one site and one cluster deployment)
* `clusters:` An array of clusters on the site
* `ceph_nodes_count:` number of nodes used for the Ceph cluster
* `node_description:` descibe where are placed MONs and OSDs. Here MON is on the first disk with the system, and we use one OSD on each others disks.

#### Multi-site deployement

See `scenarios/multisite.yaml`.

```yaml
---
- filesystem: ext4
  site: nancy
  cluster_network_interface: false
  clusters:
    - name: graphene
      ceph_nodes_count: 10
      node_description:
        mon: sda
        osd:
          - sda
- filesystem: ext4
  site: rennes
  cluster_network_interface: false
  frontend: true
  computes: 1
  clusters:
    - name: paranoia
      ceph_nodes_count: 4
      node_description:
        mon: sda
        osd:
          - sdb
          - sdc
          - sdd
          - sde
- filesystem: ext4
  site: luxembourg
  cluster_network_interface: false
  clusters:
    - name: petitprince
      ceph_nodes_count: 10
      node_description:
        mon: sda
        osd:
          - sda
```

### Start the experiment

```shell
cap start
cap provision:nodes
```

### Open a shell on the first node of the Ceph cluster

```
cap ssh:ceph
...
root@paranoia-2:~# ceph -s
    cluster 7d8ef28c-11ab-4532-830c-fc87a4c6a200
     health HEALTH_WARN too few pgs per osd (12 < min 20)
     monmap e1: 1 mons at {paranoia-2=172.16.100.2:6789/0}, election epoch 2, quorum 0 paranoia-2
     mdsmap e6: 1/1/1 up {0=3=up:active}, 2 up:standby
     osdmap e23: 16 osds: 16 up, 16 in
      pgmap v31: 192 pgs, 3 pools, 9470 bytes data, 21 objects
            11368 MB used, 8344 GB / 8802 GB avail
                 192 active+clean

root@paranoia-2:~# ceph mkpool test
  successfully created pool tests
root@paranoia-2:~# ceph -s
    cluster 7d8ef28c-11ab-4532-830c-fc87a4c6a200
     health HEALTH_OK
     monmap e1: 1 mons at {paranoia-2=172.16.100.2:6789/0}, election epoch 2, quorum 0 paranoia-2
     mdsmap e6: 1/1/1 up {0=3=up:active}, 2 up:standby
     osdmap e27: 16 osds: 16 up, 16 in
      pgmap v38: 1152 pgs, 3 pools, 9470 bytes data, 21 objects
            11388 MB used, 8344 GB / 8802 GB avail
                1152 active+clean

root@paranoia-2:~# ceph osd tree
# id	weight	type name	up/down	reweight
-1	16	root default
-3	4		host paranoia-4
10	1			osd.10	up	1	
11	1			osd.11	up	1
8	1			osd.8	up	1	
9	1			osd.9	up	1	
-4	4		host paranoia-3
4	1			osd.4	up	1	
7	1			osd.7	up	1	
6	1			osd.6	up	1	
5	1			osd.5	up	1	
-2	4		host paranoia-2
3	1			osd.3	up	1	
0	1			osd.0	up	1	
2	1			osd.2	up	1	
1	1			osd.1	up	1	
-5	4		host paranoia-5
12	1			osd.12	up	1	
14	1			osd.14	up	1	
15	1			osd.15	up	1	
13	1			osd.13	up	1	
```

### Open a shell on the frontend (puppetmaster)

```
cap ssh:frontend
...
root@parapluie-25:~# puppet cert list --all
+ "paranoia-2.rennes.grid5000.fr"   (SHA256) 70:60:8D:77:86:91:34:AA:87:13:F6:C0:25:EA:1B:6C:33:7F:C1:9F:75:61:A5:1B:2B:D7:5B:1F:31:AC:B6:4A
+ "paranoia-3.rennes.grid5000.fr"   (SHA256) 42:7B:05:1E:ED:FF:DF:C4:3C:CC:ED:13:EC:1D:55:18:09:95:8B:3B:54:B9:D9:C6:30:B9:B1:89:35:39:D9:93
+ "paranoia-4.rennes.grid5000.fr"   (SHA256) D5:C3:F2:FD:A4:65:0D:86:1A:87:6D:BA:FE:62:8E:2A:86:A8:AF:0A:CA:EF:E0:45:CC:79:42:EE:55:89:50:E5
+ "paranoia-5.rennes.grid5000.fr"   (SHA256) F0:B5:04:45:8F:CE:EB:66:B5:4F:05:71:AD:14:48:79:21:A2:BC:BF:F2:F2:F9:78:38:AF:03:A8:8B:3A:8C:1E
+ "parapluie-25.rennes.grid5000.fr" (SHA256) C9:BE:42:5A:C7:E4:51:89:90:0B:E1:A6:8C:0B:BC:5D:0D:22:64:CE:FF:73:CB:50:3E:3C:E5:42:02:D4:DC:85 (alt names: "DNS:parapluie-25.rennes.grid5000.fr", "DNS:puppet", "DNS:puppet.rennes.grid5000.fr")
```

### Stop the experiment

```shell
cap oar:clean
```

### Use reservation mode to start the experiment later

Edit `./xp.conf` file and add the `reservation` option :

```
walltime        '5:00:00'
reservation     '2014-07-01 13:00:00'
```

### Multi-site multi-cluster deployment

* Edit osd crush map to add datacenter buckets :
```
cap ceph:geo
```

* Reweight OSDs :
```
cap ceph:reweight
```

* Add a monitor per sites :
```
cap provision:hiera_mon
cap provision:nodes
cap ceph:geo_mon
cap provision:nodes
```

## Rados benchmarks

### Scenario `paranoia_4nodes_16osds_ext4`

```
grid5000-xp-ceph|master ⇒ cap ssh:ceph 
...
root@paranoia-1:~# rados mkpool bench
successfully created pool bench
root@paranoia-1:~# rados bench -p bench 60 write --no-cleanup
...
 Total time run:         60.231902
Total writes made:      7430
Write size:             4194304
Bandwidth (MB/sec):     493.426 

Stddev Bandwidth:       83.2429
Max bandwidth (MB/sec): 580
Min bandwidth (MB/sec): 0
Average Latency:        0.129699
Stddev Latency:         0.117525
Max latency:            0.793961
Min latency:            0.023329
root@paranoia-1:~# rados bench -p bench 60 seq
...
 Total time run:        20.622478
Total reads made:     7430
Read size:            4194304
Bandwidth (MB/sec):    1441.146 

Average Latency:       0.0443867
Max latency:           0.612827
Min latency:           0.003959
```

### Scenario `econome_8nodes_8osds_ext4`

```
grid5000-xp-ceph|master ⇒ cap ssh:ceph 
...
root@econome-1:~# rados mkpool bench
successfully created pool bench
root@econome-1:~# rados bench -p bench 60 write --no-cleanup
...
 Total time run:         60.621542
Total writes made:      2344
Write size:             4194304
Bandwidth (MB/sec):     154.664 

Stddev Bandwidth:       61.6968
Max bandwidth (MB/sec): 256
Min bandwidth (MB/sec): 0
Average Latency:        0.413596
Stddev Latency:         0.463992
Max latency:            4.06297
Min latency:            0.038966
root@econome-1:~# rados bench -p bench 60 seq
...
 Total time run:        7.272197
Total reads made:     2344
Read size:            4194304
Bandwidth (MB/sec):    1289.294 

Average Latency:       0.0495207
Max latency:           0.30642
Min latency:           0.004439
```
