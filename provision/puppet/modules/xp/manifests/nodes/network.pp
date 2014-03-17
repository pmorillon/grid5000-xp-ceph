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

  Augeas['eth2'] ~> Exec['/sbin/ifup eth2']

}
