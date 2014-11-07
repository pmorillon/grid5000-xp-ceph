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
XP5K::Config[:computes]   ||= 1

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
yaml_obj = YAML.load(File.read("scenarios/#{XP5K::Config[:scenario]}.yaml"))
@scenario = yaml_obj.class == Array ? yaml_obj : [yaml_obj]
def scenario; @scenario; end


# Define a OAR job for nodes of the ceph cluster
#
scenario.each do |site|

  # Manages resources per site
  resources = []
  resources << %{{type='kavlan-local'}/vlan=1} if site['cluster_network_interface']
  site['clusters'].each do |cluster|
    resources << %{{cluster='#{cluster['name']}'}/nodes=#{cluster['ceph_nodes_count']}}
  end
  resources << %{nodes=1} if site['frontend']
  resources << %{nodes=#{site['computes']}} if site['computes']
  resources << %{walltime=#{XP5K::Config[:walltime]}}

  # Manage roles per site
  roles = []
  roles << XP5K::Role.new({ :name => 'frontend', :size => 1 }) if site['frontend']
  roles << XP5K::Role.new({ :name => "computes_#{site['site']}", :size => site['computes'] }) if site['computes']
  site['clusters'].each do |cluster|
    roles << XP5K::Role.new({
      :name    => "ceph_nodes_#{cluster['name']}",
      :size    => cluster['ceph_nodes_count'],
      :pattern => cluster['name']
    })
    roles << XP5K::Role.new({
      :name => "ceph_monitor_#{cluster['name']}",
      :size => 1,
      :inner => "ceph_nodes_#{cluster['name']}"
    })
  end

  job_description = {
    :resources => resources.join(","),
    :site      => site['site'],
    :queue     => XP5K::Config[:queue] || 'default',
    :types     => ["deploy"],
    :name      => "xp5k_ceph_#{site['site']}",
    :roles     => roles,
    :command   => "sleep 186400"
  }
  job_description[:reservation] = XP5K::Config[:reservation] if not XP5K::Config[:reservation].nil?
  xp.define_job(job_description)

  # Define deployment on all nodes
  #
  xp.define_deployment({
    :site          => site['site'],
    :environment   => "wheezy-x64-base",
    :jobs          => ["xp5k_ceph_#{site['site']}"],
    :key           => File.read(XP5K::Config[:public_key]),
    :notifications => ["xmpp:#{XP5K::Config[:user]}@jabber.grid5000.fr"]
  })

end


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
  nodes = []
  scenario.each do |site|
    site['clusters'].each do |cluster|
      nodes << xp.role_with_name("ceph_nodes_#{cluster['name']}").servers
    end
  end
  nodes.flatten!
end

role :ceph_monitor do
  nodes = []
  scenario.each do |site|
    site['clusters'].each do |cluster|
      nodes << xp.role_with_name("ceph_monitor_#{cluster['name']}").servers
    end
  end
  nodes.flatten!.first
end

role :ceph_monitors do
  nodes = []
  scenario.each do |site|
    site['clusters'].each do |cluster|
      nodes << xp.role_with_name("ceph_monitor_#{cluster['name']}").servers
    end
  end
  # Fixme : manage multiple monitors
  #nodes.first
  nodes.flatten!
end


role :computes do
  nodes = []
  scenario.each do |site|
    nodes << xp.role_with_name("computes_#{site['site']}").servers if site['computes']
  end
  nodes.flatten!
end

role :empty do
  []
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
before :start, "provision:all"
before :start, "os:ntp"
before :start, "provision:hiera_osd"
before :start, "provision:create_osd"
before :start, "os:umount_tmp"
before :start, "provision:nodes"


# Empty task for the `start` workflow
#
desc "Start the experiment"
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
  task :setup_agent, :roles => [:frontend, :ceph_nodes, :computes] do
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
    run "http_proxy=http://proxy:3128 https_proxy=http://proxy:3128 puppet agent -t --parser future --server #{xp.role_with_name("frontend").servers.first}"
  end

  before 'provision:computes', 'provision:upload_modules'

  desc 'Provision computes'
  task :computes, :roles => :computes, :on_error => :continue do
    set :user, 'root'
    run "http_proxy=http://proxy:3128 https_proxy=http://proxy:3128 puppet agent -t --server #{xp.role_with_name("frontend").servers.first}"
  end

  before 'provision:all', 'provision:upload_modules'

  desc 'Provision all puppet agents (ceph nodes and computes nodes)'
  task :all, :roles => [:computes, :ceph_nodes], :on_error => :continue do
    set :user, 'root'
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
    nodes = []
    scenario.each do |site|
      site['clusters'].each do |cluster|
        nodes << xp.role_with_name("ceph_nodes_#{cluster['name']}").servers
      end
    end
    nodes.flatten!
    nodes.each do |node|
      File.open("provision/hiera/db/#{node}.yaml", 'w') do |file|
        file.puts({ 'classes' => %w{ xp::nodes xp::ceph::osd } }.to_yaml)
      end
    end
    # Fixme: multiple monitor support
    #serversForCapRoles("ceph_monitor").each do |monitor|
      #File.open("provision/hiera/db/#{monitor}.yaml", "w") do |file|
        #file.puts({ 'classes' => %w{ xp::nodes xp::ceph::osd xp::ceph::mon } }.to_yaml)
      #end
    #end
    File.open("provision/hiera/db/#{serversForCapRoles("ceph_monitor").first}.yaml", "w") do |file|
      file.puts({ 'classes' => %w{ xp::nodes xp::ceph::osd xp::ceph::mon::initial xp::ceph::mds xp::ceph::radosgw } }.to_yaml)
    end
    synced = false
  end

  desc "Configure Hiera for secondary monitors"
  task :hiera_mon do
    serversForCapRoles("ceph_monitors")[1..-1].each do |monitor|
      File.open("provision/hiera/db/#{monitor}.yaml", "w") do |file|
        file.puts({ 'classes' => %w{ xp::nodes xp::ceph::osd xp::ceph::mon::others } }.to_yaml)
      end
    end
    synced = false
  end

  before 'provision:create_osd', 'provision:upload_modules'

  desc "Creates OSD"
  task :create_osd, :roles => :ceph_monitor do
    set :user, 'root'
    hiera = YAML.load(File.read('provision/hiera/db/xp.yaml'))
    ceph_description = hiera["ceph_description"]
    ceph_description.each do |hostname,desc|
      cmd = Array.new(desc['osd'].length) { |i| "ceph osd create" }.join(" && ")
      run cmd
    end
  end

end


# Tasks for ceph cluster operations
#
namespace :ceph do

  desc 'Create geo map'
  task :geo, :roles => :ceph_monitor do
    set :user, 'root'
    scenario.each do |site|
      run "ceph osd crush add-bucket #{site['site']} datacenter"
      run "ceph osd crush move #{site['site']} root=default"
      site['clusters'].each do |cluster|
        xp.role_with_name("ceph_nodes_#{cluster['name']}").servers.each do |node|
          run "ceph osd crush move #{node.split(".").first} datacenter=#{site['site']}"
        end
      end
    end
  end

  desc 'Reweight OSDs'
  task :reweight, :roles => :ceph_nodes do
    set :user, 'root'
    run %{for i in $(ls /var/lib/ceph/osd); do ceph osd crush reweight osd.$(echo $i | cut -d'_' -f2) $(echo "scale=3;($(df /var/lib/ceph/osd/$i | grep osd | awk '{print $2;}')/(1024^3))" | bc); done}
  end

  desc 'Configure Ceph in order to use the nearest monitors, need to have several monitors and a valid paxos quorum'
  task :geo_mon do
    xpconfig = YAML.load(File.read('provision/hiera/db/xp.yaml'))
    xpconfig['quorum'] = true
    File.open('provision/hiera/db/xp.yaml', 'w') do |file|
      file.puts xpconfig.to_yaml
    end
  end

end


# Tasks for system coponents
#
namespace :os do

  desc 'Fixes time issue'
  task :ntp, :roles => :ceph_nodes do
    set :user, 'root'
    run "service ntp stop && ntpdate ntp && service ntp start"
  end

  # Task to umount /tmp on ceph nodes
  #
  desc "umount /tmp on"
  task :umount_tmp, :roles => :ceph_nodes do
    set :user, "root"
    run "umount /tmp"
  end

end

# Tasks for open a shell on nodes
#
namespace :ssh do

  desc "ssh on the ceph monitor node"
  task :ceph do
    fork_exec('ssh', SSH_CONFIGFILE_OPT.split(" "), 'root@' + serversForCapRoles('ceph_monitor').first)
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
    # Only manage local vlan when deploying ceph on one site
    if scenario.length == 1
      scenario.each do |site|
        next if not site['cluster_network_interface']
        vlanid = xp.job_with_name("xp5k_ceph_#{site['site']}")['resources_by_type']['vlans'].first.to_i
        nodes = []
        site['clusters'].each do |cluster|
          nodes << xp.role_with_name("ceph_nodes_#{cluster['name']}").servers.map { |node| node.gsub(/-(\d+)/, '-\1-' + site['cluster_network_interface']) }
        end
        logger.info "Setting in vlan #{vlanid} following nodes : #{nodes.inspect}"
        root = xp.connection.root.sites[site['site'].to_sym]
        vlan = root.vlans.find { |item| item['uid'] == vlanid.to_s }
        vlan.submit :nodes => nodes
      end
    end
  end

end


# Task for commands
#
desc "run command on computes nodes (need CMD and ROLES, computes by default)"
task :cmd, :roles => :empty do
  raise "Need CMD environment variable" unless ENV['CMD']
  raise "Need ROLES environment variable" unless ENV['ROLES']
  set :user, 'root'
  run ENV['CMD']
end

# List servers from capistrano roles
#
def serversForCapRoles(roles)
  find_servers(:roles => roles).collect { |x| x.host }
end

# Manage the Hiera database
#
def generateHieraDatabase
  # Remove old databases from previous experiments
  %x{rm -f provision/hiera/db/*}

  # Manage Vlan or not
  if (scenario.length == 1 and scenario.first['cluster_network_interface'])
    vlan = xp.job_with_name("ceph_nodes")['resources_by_type']['vlans'].first
  else
    vlan = 0
  end

  # Generate ceph hierarchy
  clusters_description = {}
  cluster_network_interface = {}
  ceph_description = {}
  osd_id = 0
  scenario.each do |site|
    cluster_network_interface[site['site']] = site['cluster_network_interface']
    site['clusters'].each do |cluster|
      clusters_description[cluster['name']] = cluster['node_description']
      xp.role_with_name("ceph_nodes_#{cluster['name']}").servers.each do |node|
        ceph_description[node] ||= {}
        cluster['node_description']['osd'].each do |osd|
          ceph_description[node]['osd'] ||= []
          ceph_description[node]['osd'] << {
            'id'    => osd_id,
            'device' => osd,
            'fs'     => site['filesystem']
          }
          osd_id += 1
        end
        ceph_description[node]['mon'] = { 'device' => cluster['node_description']['mon'] }
      end
    end
  end

  # Add experiment configuration into Hiera
  xpconfig = {
    'frontend'                   => xp.role_with_name("frontend").servers.first,
    'ceph_monitors'              => serversForCapRoles("ceph_monitors"),
    'ceph_mds'                   => serversForCapRoles("ceph_monitor"),
    'ceph_nodes'                 => serversForCapRoles("ceph_nodes"),
    'computes'                   => serversForCapRoles("computes"),
    'vlan'                       => vlan,
    'cluster_network_interfaces' => cluster_network_interface,
    'ceph_fsid'                  => '7D8EF28C-11AB-4532-830C-FC87A4C6A200',
    'ceph_description'           => ceph_description,
    'osd_count'                  => osd_id,
    'fs'                         => 'ext4',
    'quorum'                     => false
  }
  FileUtils.mkdir('provision/hiera/db') if not Dir.exists?('provision/hiera/db')
  File.open('provision/hiera/db/xp.yaml', 'w') do |file|
    file.puts xpconfig.to_yaml
  end

  # Configure Puppet classes to apply on each nodes
  scenario.each do |site|
    site['clusters'].each do |cluster|
      serversForCapRoles("ceph_nodes").each do |node|
        File.open("provision/hiera/db/#{node}.yaml", 'w') do |file|
          file.puts({ 'classes' => %w{ xp::nodes } }.to_yaml)
        end
      end
      File.open("provision/hiera/db/#{serversForCapRoles("ceph_monitor").first}.yaml", 'w') do |file|
        file.puts({ 'classes' => %w{ xp::nodes xp::ceph::mon::initial } }.to_yaml)
      end
    end
  end
  serversForCapRoles("computes").each do |node|
    File.open("provision/hiera/db/#{node}.yaml", 'w') do |file|
        file.puts({ 'classes' => %w{ xp::computes } }.to_yaml)
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

