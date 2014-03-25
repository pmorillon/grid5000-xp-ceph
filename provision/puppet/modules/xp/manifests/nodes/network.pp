class xp::nodes::network {

  augeas {
    'eth2':
      context => '/files/etc/network/interfaces',
      changes => [
        "set iface[. = 'eth2'] eth2",
        "set iface[. = 'eth2']/family inet",
        "set iface[. = 'eth2']/method dhcp"
      ]
  }

  exec {
    '/sbin/ifup eth2':
      refreshonly => true;
  }

  file {
    '/etc/dhcp/dhclient-exit-hooks.d/g5k-update-host-name':
      ensure => absent;
  }

  File['/etc/dhcp/dhclient-exit-hooks.d/g5k-update-host-name'] -> Augeas['eth2']
  Augeas['eth2'] ~> Exec['/sbin/ifup eth2']

}
