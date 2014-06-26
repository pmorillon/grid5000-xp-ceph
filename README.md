# Ceph cluster deployment on Grid'5000

With this experiment, you can easily deploy a Ceph cluster on 8 nodes (32 OSDs), linked with a 10Gb/s network, for a final amount of 17TB of storage.

The goal of this experiment is to benchmark a Ceph cluster on Grid'5000 and compare the usage of `ext4` and `xfs` on OSDs, usage of a dedicated private network for replication, etc...

## Setup

### For usage from Grid'5000

#### Clone the repository

You can work from your workstation without to connect onto a Grid'5000 frontend.

	$ git clone git@github.com:pmorillon/grid5000-xp-ceph.git
	$ cd grid5000-xp-ceph

#### Configure your environment

	$ export PATH=~/.gem/ruby/1.9.1/bin:$PATH
	$ export http_proxy=http://proxy:3128
	$ export https_proxy=http://proxy:3128

#### Install Rugygems dependencies with Bundler

	$ gem install --user bundler
	$ bundle install --path ~/.gem

#### Configure Restfully

	$ mkdir -p ~/.restfully && echo '
	uri: https://api.grid5000.fr/3.0/' > ~/.restfully/api.grid5000.fr.yml && chmod 600 ~/.restfully/api.grid5000.fr.yml

#### Configure XP5K

Create the file `xp.conf` into the `grid5000-xp-ceph` directory.

	# OAR jobs defaults
	walltime        '2:00:00'

	# Your Grid'5000 login
	user            'mylogin'
		
	# SSH configuration
	public_key      File.expand_path '~/.ssh/id_rsa.pub'
	ssh_config      File.expand_path '~/.ssh/config'

	# Choose a scenario (see ./scenarios directory)
	scenario        'ext4_4osd_per_nodes'


### For external usage

#### Clone the repository

You can work from your workstation without to connect onto a Grid'5000 frontend.

	$ git clone git@github.com:pmorillon/grid5000-xp-ceph.git
	$ cd grid5000-xp-ceph
	
#### Install Rugygems dependencies with Bundler

Assuming that you use [RVM](https://rvm.io/) (Ruby Version Manager) :

	$ bundle install

#### Configure Restfully

Configure [Restfully for an external access](https://api.grid5000.fr/doc/3.0/tools/restfully.html#how-do-i-avoid-passing-my-password-each-time-i-want-to-use-restfully).

#### Configure XP5K

Create the file `xp.conf` into the `grid5000-xp-ceph` directory.

	# OAR jobs defaults
	walltime        '2:00:00'

	# Your Grid'5000 login
	user            'mylogin'
		
	# SSH configuration
	public_key      File.expand_path '~/.ssh/id_rsa_g5k_external.pub'
	gateway         "#{self[:user]}@frontend.rennes.grid5000.fr"
	ssh_config      File.expand_path '~/.ssh/config_xp5k'

	# Choose a scenario (see ./scenarios directory)
	scenario        'ext4_4osd_per_nodes'


#### Configure ssh config file

[https://www.grid5000.fr/mediawiki/index.php/Xp5k#SSH](https://www.grid5000.fr/mediawiki/index.php/Xp5k#SSH)

## Usage

	$ cap start
	$ cap provision:nodes

To stop the experiment

	$ oar:clean
