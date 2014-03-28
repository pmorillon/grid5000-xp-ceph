class xp::ceph {

  include '::ceph'
  include 'xp::ceph::osd'
  include 'xp::ceph::mon'

  $node_description = hiera_hash('node_description')
  $osd_devices = $node_description['osd']
  $fs = hiera('filesystem')
  $nodes = hiera_array('ceph_nodes')
  $vlan_id = hiera('vlan')

  package {
    ['xfsprogs', 'parted']:
      ensure => installed;
  }

  file {
    '/srv/ceph':
      tag    => 'ceph_tree';
  }

  file {
    '/etc/ceph/ceph.conf':
      ensure  => file,
      mode    => '0644',
      owner   => root,
      group   => root,
      content => template('xp/ceph/ceph.conf.erb'),
      require => Package['ceph'];
    '/root/.ssh/id_rsa':
      ensure => file,
      mode   => '0600',
      owner  => root,
      group  => root,
      source => "puppet://${puppetmaster}/xpfiles/id_rsa_ceph";
    '/root/.ssh/id_rsa.pub':
      ensure => file,
      mode   => '0644',
      owner  => root,
      group  => root,
      source => "puppet://${puppetmaster}/xpfiles/id_rsa_ceph.pub";
  }

  exec {
    'cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys':
      path    => "/usr/bin:/usr/sbin:/bin",
      user    => root,
      group   => root,
      unless  => 'grep ceph /root/.ssh/authorized_keys',
      require => File['/root/.ssh/id_rsa.pub'];
  }

}
