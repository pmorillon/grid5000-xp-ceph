class xp::ceph::mds {

  require 'xp::ceph'

  File <| tag == 'ceph_tree' |> {
    ensure => directory,
    mode   => '0644',
    owner  => root,
    group  => root
  }

  $nodes = hiera_array('ceph_nodes')
  $node_id = get_array_id($nodes, $fqdn)

  file {
    "${xp::ceph::path}/mds/ceph-${hostname}":
      tag => 'ceph_tree';
  }

  exec {
    'Create mds key':
      command => "/usr/bin/ceph auth get-or-create mds.${hostname} mds 'allow' osd 'allow rwx' mon 'allow profile mds' > ${xp::ceph::path}/mds/ceph-${hostname}/keyring",
      creates => "${xp::ceph::path}/mds/ceph-${hostname}/keyring",
      require => [Package['ceph'], File["${xp::ceph::path}/mds/ceph-${hostname}"]];
  }

  service {
    "ceph-mds":
      ensure  => running,
      start   => "service ceph start mds.${hostname}",
      stop    => "service ceph stop mds.${hostname}",
      status  => "service ceph status mds.${hostname}",
      require => Exec['Populate the monitor daemon'];
  }

}
