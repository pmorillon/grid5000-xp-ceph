class xp::ntp {

  package {
    ['ntp', 'ntpdate']:
      ensure => installed;
  }

  service {
    'ntp':
      ensure => running,
      enable => true;
  }

  file {
    '/etc/ntp.conf':
      ensure => file,
      mode   => '0644',
      owner  => root,
      group  => root,
      source => 'puppet:///modules/xp/ntp/ntp.conf';
  }

  Package['ntp'] -> File['/etc/ntp.conf'] ~> Service['ntp']

}
