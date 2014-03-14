class xp::apache {

  package {
    'apache2':
      ensure => installed;
  }

  service {
    'apache2':
      ensure => running,
      enable => true;
  }

  Package['apache2'] -> Service['apache2']

}
