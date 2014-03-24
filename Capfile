# Capfile
## -*- mode: ruby -*-
## vi: set ft=ruby :

require "xp5k"

PUPPET_VERSION = '3.4.2'

XP5K::Config.load
@xp = XP5K::XP.new(:logger => logger)
def xp; @xp; end
experiment_walltime = XP5K::Config[:walltime] || "1:00:00"
sync_path = File.expand_path(File.join(Dir.pwd, 'provision'))
synced = false

xp.define_job({
  :resources  => %{{type='kavlan-local'}/vlan=1,{ethnb=2}/nodes=#{(XP5K::Config[:nodes_count] || 3) + 1},walltime=#{experiment_walltime}},
  :site       => XP5K::Config[:site] || 'rennes',
  :queue      => XP5K::Config[:queue] || 'default',
  :types      => ["deploy"],
  :name       => "ceph",
  :roles      => [
    XP5K::Role.new({ :name => 'frontend', :size => 1 }),
    XP5K::Role.new({ :name => 'ceph_nodes', :size => XP5K::Config[:nodes_count] || 3 }),
  ],
  :command    => "sleep 186400"
})

xp.define_deployment({
  :site           => XP5K::Config[:site],
  :environment    => "wheezy-x64-base",
  :roles          => %w{ frontend ceph_nodes },
  :key            => File.read(XP5K::Config[:public_key]),
  :notifications  => ["xmpp:#{XP5K::Config[:user]}@jabber.grid5000.fr"]
})


SSH_CMD = "ssh -o ConnectTimeout=10 -F #{XP5K::Config[:ssh_config] || '~/.ssh/config'}"

set :gateway, XP5K::Config[:gateway] if XP5K::Config[:gateway]
set :ssh_config, XP5K::Config[:ssh_config] if XP5K::Config[:ssh_config]

role :g5kfrontend, "frontend.#{XP5K::Config[:site]}.grid5000.fr"

role :frontend do
  xp.role_with_name("frontend").servers
end

role :ceph_nodes do
  xp.role_with_name("ceph_nodes").servers
end

before :start, "oar:submit"
before :start, "kadeploy:submit"
before :start, "provision:setup_agent"
before :start, "provision:setup_server"
before :start, "provision:frontend"
before :start, "provision:nodes"
before :start, "vlan:set"

task :start do

end

namespace :oar do
  desc "Submit OAR jobs"
  task :submit do
    xp.submit
  end

  desc "Clean all running OAR jobs"
  task :clean do
    logger.debug "Clean all Grid'5000 running jobs..."
    xp.clean
  end

  desc "OAR jobs status"
  task :status do
    xp.status
  end
end

namespace :kadeploy do
  desc "Submit kadeploy deployments"
  task :submit do
    xp.deploy
  end
end

namespace :provision do
  desc "Install puppet agent"
  task :setup_agent, :roles => [:frontend, :ceph_nodes] do
    set :user, "root"
    run 'apt-get update && apt-get -y install curl wget'
    run "http_proxy=http://proxy:3128 https_proxy=http://proxy:3128 wget -O /tmp/puppet_install.sh https://raw.github.com/pmorillon/puppet-puppet/0.0.3/extras/scripts/puppet_install.sh"
    run "http_proxy=http://proxy:3128 https_proxy=http://proxy:3128 PUPPET_VERSION=#{PUPPET_VERSION} sh /tmp/puppet_install.sh"
  end

  desc "Install Puppet master"
  task :setup_server, :roles => :frontend do
    set :user, "root"
    run "apt-get -y install puppetmaster=#{PUPPET_VERSION}-1puppetlabs1 puppetmaster-common=#{PUPPET_VERSION}-1puppetlabs1"
  end

  before 'provision:frontend', 'provision:upload_modules'

  desc "Provision frontend"
  task :frontend, :roles => :frontend do
    set :user, "root"
    upload "provision/hiera/hiera.yaml", "/etc/puppet/hiera.yaml"
    run "http_proxy=http://proxy:3128 https_proxy=http://proxy:3128 puppet apply --modulepath=/srv/provision/puppet/modules:/srv/provision/puppet/external-modules -e 'include xp::puppet::master'"
  end

  before 'provision:nodes', 'provision:upload_modules'

  desc "Provision nodes"
  task :nodes, :roles => :ceph_nodes do
    set :user, "root"
    run "http_proxy=http://proxy:3128 https_proxy=http://proxy:3128 puppet agent -t --server #{xp.role_with_name("frontend").servers.first}"
  end

  desc "Upload modules on Puppet master"
  task :upload_modules do
    unless synced
      generateHieraDatabase
      %x{rsync -e '#{SSH_CMD}' -rl --delete --exclude '.git*' #{sync_path} root@#{xp.role_with_name("frontend").servers.first}:/srv}
      synced = true
    end
  end

end

namespace :vlan do

  desc "Set nodes into vlan"
  task :set do
    vlanid = xp.job_with_name("ceph")['resources_by_type']['vlans'].first.to_i
    nodes = xp.role_with_name("ceph_nodes").servers.map { |node| node.gsub(/-(\d+)/, '-\1-eth2') }
    logger.info "Setting in vlan #{vlanid} following nodes : #{nodes.inspect}"
    root = xp.connection.root.sites[XP5K::Config[:site].to_sym]
    vlan = root.vlans.find { |item| item['uid'] == vlanid.to_s }
    vlan.submit :nodes => nodes
  end

end

def generateHieraDatabase
  %x{rm -f provision/hiera/db/*}
  xpconfig = {
    'frontend'   => xp.role_with_name("frontend").servers.first,
    'ceph_nodes' => xp.role_with_name("ceph_nodes").servers
  }
  File.open('provision/hiera/db/xp.yaml', 'w') do |file|
    file.puts xpconfig.to_yaml
  end
  classes = {
    'classes' => %w{ xp::nodes }
  }
  xp.role_with_name("ceph_nodes").servers.each do |node|
    File.open("provision/hiera/db/#{node}.yaml", 'w') do |file|
      file.puts classes.to_yaml
    end
  end
end

