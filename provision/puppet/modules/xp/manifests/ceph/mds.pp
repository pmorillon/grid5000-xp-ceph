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
    "/srv/ceph/mds.${node_id}":
      tag => 'ceph_tree';
  }

  exec {
    'Create mds key':
      command => "/usr/bin/ceph auth get-or-create mds.${node_id} mds 'allow ' osd 'allow *' mon 'allow rwx' > /srv/ceph/mds.${node_id}/keyring",
      creates => "/srv/ceph/mds.${node_id}/keyring",
      require => [Package['ceph'], File["/srv/ceph/mds.${node_id}"]];
  }

  service {
    "ceph-mds":
      ensure  => running,
      start   => "service ceph start mds.${node_id}",
      stop    => "service ceph stop mds.${node_id}",
      status  => "service ceph status mds.${node_id}",
      require => Exec['Populate the monitor daemon'];
  }

}
