# Capfile
## -*- mode: ruby -*-
## vi: set ft=ruby :

require "xp5k"
require "yaml"


# Load ./xp.conf file
#
XP5K::Config.load


# Initialize experiment
#
@xp = XP5K::XP.new(:logger => logger)
def xp; @xp; end


# Defaults configuration
#
XP5K::Config[:scenario]   ||= 'paranoia_4nodes_16osds_ext4'
XP5K::Config[:walltime]   ||= '1:00:00'
XP5K::Config[:user]       ||= ENV['USER']

# Constants
#
PUPPET_VERSION = '3.4.2'
SSH_CONFIGFILE_OPT = XP5K::Config[:ssh_config].nil? ? "" : " -F " + XP5K::Config[:ssh_config]
SSH_CMD = "ssh -o ConnectTimeout=10" + SSH_CONFIGFILE_OPT


# Define vars used for file synchronization between local repo and the puppet master
#
sync_path = File.expand_path(File.join(Dir.pwd, 'provision'))
synced = false


# Load scenario
#
@scenario = YAML.load(File.read("scenarios/#{XP5K::Config[:scenario]}.yaml"))
def scenario; @scenario; end


# Define a OAR job for nodes of the ceph cluster
#
job_description = {
  :resources  => %{{type='kavlan-local'}/vlan=1,{cluster='#{scenario['cluster']}'}/nodes=#{scenario['ceph_nodes_count']},walltime=#{XP5K::Config[:walltime]}},
  :site       => XP5K::Config[:site] || scenario[:site] || 'rennes',
  :queue      => XP5K::Config[:queue] || 'default',
  :types      => ["deploy"],
  :name       => "ceph_nodes",
  :roles      => [
    XP5K::Role.new({ :name => 'ceph_nodes', :size => scenario['ceph_nodes_count'] }),
    XP5K::Role.new({ :name => 'ceph_monitor', :size => 1, :inner => 'ceph_nodes'})
  ],
  :command    => "sleep 186400"
}
job_description[:reservation] = XP5K::Config[:reservation] if not XP5K::Config[:reservation].nil?
xp.define_job(job_description)


# Define a OAR job for the frontend (puppetmaster) and computes nodes
#
job_description = {
  :resources  => %{nodes=2,walltime=#{XP5K::Config[:walltime]}},
  :site       => XP5K::Config[:site] || scenario['site'] || 'rennes',
  :queue      => 'default',
  :types      => ["deploy"],
  :name       => "ceph_frontend",
  :roles      => [
    XP5K::Role.new({ :name => 'frontend', :size => 1 }),  # For the puppet master
    XP5K::Role.new({ :name => 'computes', :size => 1 })
  ],
  :command    => "sleep 186400"
}
job_description[:reservation] = XP5K::Config[:reservation] if not XP5K::Config[:reservation].nil?
xp.define_job(job_description)


# Define deployment on all nodes
#
xp.define_deployment({
  :site           => scenario['site'],
  :environment    => "wheezy-x64-base",
  :roles          => %w{ frontend ceph_nodes computes },
  :key            => File.read(XP5K::Config[:public_key]),
  :notifications  => ["xmpp:#{XP5K::Config[:user]}@jabber.grid5000.fr"]
})


# Configure SSH for capistrano
#
set :gateway, XP5K::Config[:gateway] if XP5K::Config[:gateway]
set :ssh_config, XP5K::Config[:ssh_config] if XP5K::Config[:ssh_config]


# Define roles
#
role :frontend do
  xp.role_with_name("frontend").servers
end

role :ceph_nodes do
  xp.role_with_name("ceph_nodes").servers
end

role :ceph_monitor do
  xp.role_with_name("ceph_monitor").servers
end


# Define the workflow
#
before :start, "oar:submit"
before :start, "kadeploy:submit"
before :start, "provision:setup_agent"
before :start, "provision:setup_server"
before :start, "provision:hiera_generate"
before :start, "provision:frontend"
before :start, "vlan:set"
before :start, "provision:nodes"
before :start, "provision:hiera_osd"
before :start, "provision:create_osd"
before :start, "provision:nodes"


# Empty task for the `start` workflow
#
task :start do
end


# Tasks for OAR job management
#
namespace :oar do
  desc "Submit OAR jobs"
  task :submit do
    xp.submit
    xp.wait_for_jobs
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


# Tasks for deployments management
#
namespace :kadeploy do
  desc "Submit kadeploy deployments"
  task :submit do
    xp.deploy
  end
end


# Tasks for Puppet provisioning
#
namespace :provision do
  desc "Install puppet agent"
  task :setup_agent, :roles => [:frontend, :ceph_nodes] do
    set :user, "root"
    run 'apt-get update && apt-get -y install curl wget'
    run "http_proxy=http://proxy:3128 https_proxy=http://proxy:3128 wget -O /tmp/puppet_install.sh https://raw.githubusercontent.com/pmorillon/puppet-puppet/master/extras/bootstrap/puppet_install.sh"
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
    run "http_proxy=http://proxy:3128 https_proxy=http://proxy:3128 puppet apply --modulepath=/srv/provision/puppet/modules -e 'include xp::frontend'"
  end

  before 'provision:nodes', 'provision:upload_modules'

  desc "Provision nodes"
  task :nodes, :roles => :ceph_nodes, :on_error => :continue do
    set :user, "root"
    run "http_proxy=http://proxy:3128 https_proxy=http://proxy:3128 puppet agent -t --server #{xp.role_with_name("frontend").servers.first}"
  end

  desc "Upload modules on Puppet master"
  task :upload_modules do
    unless synced
      %x{rsync -e '#{SSH_CMD}' -rl --delete --exclude '.git*' #{sync_path} root@#{xp.role_with_name("frontend").servers.first}:/srv}
      synced = true
    end
  end

  desc "Generate hiera databases"
  task :hiera_generate do
    generateHieraDatabase
  end

  desc "Add osd to Hiera"
  task :hiera_osd do
    xp.role_with_name("ceph_nodes").servers.each do |node|
      File.open("provision/hiera/db/#{node}.yaml", 'w') do |file|
        file.puts({ 'classes' => %w{ xp::nodes xp::ceph::osd xp::ceph::mon } }.to_yaml)
      end
    end
    File.open("provision/hiera/db/#{xp.role_with_name("ceph_monitor").servers.first}.yaml", "w") do |file|
      file.puts({ 'classes' => %w{ xp::nodes xp::ceph::osd xp::ceph::mon xp::ceph::mds } }.to_yaml)
    end
    synced = false
  end

  before 'provision:create_osd', 'provision:upload_modules'

  desc "Creates OSD"
  task :create_osd, :roles => :ceph_monitor do
    set :user, 'root'
    hiera = YAML.load(File.read('provision/hiera/db/xp.yaml'))
    nodes = hiera["ceph_nodes"]
    devices = hiera["node_description"]["osd"]
    cmd = Array.new(devices.length) { |i| "ceph osd create" }.join(" && ")
    nodes.each do
      run cmd
    end
  end

end


# Tasks for open a shell on nodes
#
namespace :ssh do

  desc "ssh on the ceph monitor node"
  task :ceph do
    fork_exec('ssh', SSH_CONFIGFILE_OPT.split(" "), 'root@' + xp.role_with_name('ceph_monitor').servers.first)
  end

  desc "ssh on the frontend (puppetmaster)"
  task :frontend do
    fork_exec('ssh', SSH_CONFIGFILE_OPT.split(" "), 'root@' + xp.role_with_name('frontend').servers.first)
  end

end


# Tasks for Vlan management
#
namespace :vlan do

  desc "Set nodes into vlan"
  task :set do
    vlanid = xp.job_with_name("ceph_nodes")['resources_by_type']['vlans'].first.to_i
    nodes = xp.role_with_name("ceph_nodes").servers.map { |node| node.gsub(/-(\d+)/, '-\1-eth2') }
    logger.info "Setting in vlan #{vlanid} following nodes : #{nodes.inspect}"
    root = xp.connection.root.sites[scenario['site'].to_sym]
    vlan = root.vlans.find { |item| item['uid'] == vlanid.to_s }
    vlan.submit :nodes => nodes
  end

end


# Manage the Hiera database
#
def generateHieraDatabase
  # Remove old databases from previous experiments
  %x{rm -f provision/hiera/db/*}

  # Add experiment configuration into Hiera
  xpconfig = {
    'frontend'     => xp.role_with_name("frontend").servers.first,
    'ceph_nodes'   => xp.role_with_name("ceph_nodes").servers,
    'ceph_monitor' => xp.role_with_name("ceph_monitor").servers.first,
    'ceph_mds'     => xp.role_with_name("ceph_monitor").servers.first,
    'vlan'         => xp.job_with_name("ceph_nodes")['resources_by_type']['vlans'].first,
    'ceph_fsid'    => '7D8EF28C-11AB-4532-830C-FC87A4C6A200'
  }
  xpconfig.merge!(YAML.load(File.read("scenarios/#{XP5K::Config[:scenario]}.yaml")))
  FileUtils.mkdir('provision/hiera/db') if not Dir.exists?('provision/hiera/db')
  File.open('provision/hiera/db/xp.yaml', 'w') do |file|
    file.puts xpconfig.to_yaml
  end

  # Configure Puppet classes to apply on each nodes
  xp.role_with_name("ceph_nodes").servers.each do |node|
    File.open("provision/hiera/db/#{node}.yaml", 'w') do |file|
      file.puts({ 'classes' => %w{ xp::nodes xp::ceph::mon } }.to_yaml)
    end
  end
end


# Fork the execution of a command. Used to execute ssh on deployed nodes.
#
def fork_exec(command, *args)
  # Remove empty args
  args.select! { |arg| arg != "" }
  args.flatten!
  pid = fork do
    Kernel.exec(command, *args)
  end
  Process.wait(pid)
end

