# Ceph cluster deployment on Grid'5000

With this experiment, you can easily deploy a Ceph cluster on 8 nodes (32 OSDs), linked with a 10Gb/s network, for a final amount of 17TB of storage.

The goal of this experiment is to benchmark a Ceph cluster on Grid'5000 and compare the usage of `ext4` and `xfs` on OSDs, usage of a dedicated private network for replication, etc...

## Setup

### Clone the repository

You can work from your workstation without to connect onto a Grid'5000 frontend.

	$ git clone git@github.com:pmorillon/grid5000-xp-ceph.git
	$ cd grid5000-xp-ceph

### Install Rugygems dependencies with Bundler

	$ gem install bundler
	$ bundle install

### Configure Restfully

Configure [Restfully for an external access](https://api.grid5000.fr/doc/3.0/tools/restfully.html#how-do-i-avoid-passing-my-password-each-time-i-want-to-use-restfully).

### Configure XP5K

Create the file `xp.conf` into the `grid5000-xp-ceph` directory.

	# OAR jobs defaults
	walltime        '2:00:00'

	# Your Grid'5000 login
	user            'mylogin'
		
	# SSH configuration
	public_key      '~/.ssh/my_g5k_public_key.pub'
	gateway         "#{self[:user]}@frontend.rennes.grid5000.fr"
	ssh_config      '~/.ssh/config_xp5k'

	# Choose a scenario (see ./scenarios directory)
	scenario        'ext4_4osd_per_nodes'

### Configure ssh config file

[https://www.grid5000.fr/mediawiki/index.php/Xp5k#SSH](https://www.grid5000.fr/mediawiki/index.php/Xp5k#SSH)

## Usage

	$ bundle exec cap start
	$ bundle exec cap provision:nodes

To stop the experiment

	$ bundle exec cap oar:clean
