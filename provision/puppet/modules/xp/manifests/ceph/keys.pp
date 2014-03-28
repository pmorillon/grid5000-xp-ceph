class xp::ceph::keys {

  exec {
    'Generate ceph keys':
      path    => "/usr/bin:/usr/sbin:/bin",
      command => "ssh-keygen -t rsa -C ceph_key -f /etc/puppet/exports/xpfiles/id_rsa_ceph",
      user    => root,
      group   => root,
      creates => "/etc/puppet/exports/xpfiles/id_rsa_ceph",
      require => File['/etc/puppet/exports/xpfiles'];
  }

  file {
    '/etc/puppet/exports/xpfiles/id_rsa_ceph':
      mode  => '0640',
      owner => root,
      group => puppet;
    '/etc/puppet/exports/xpfiles/id_rsa_ceph.pub':
      mode  => '0644',
      owner => root,
      group => puppet;
  }

}
