class xp::computes {

  include 'xp::nodes'

  file {
    '/etc/ceph/cephfs_sercretfile':
      ensure => file,
      mode   => '0640',
      owner  => root,
      group  => root,
      source => "puppet://${puppetmaster}/xpfiles/secretfile";
    '/mnt/cephfs':
      ensure => directory,
      mode   => '0755',
      owner  => root,
      group  => root;
  }

}
