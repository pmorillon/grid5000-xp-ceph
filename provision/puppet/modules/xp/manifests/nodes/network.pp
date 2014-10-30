class xp::nodes::network {

  $cluster_network_interfaces = hiera_hash('cluster_network_interfaces')
  $interface = $cluster_network_interfaces[$site]

  if $interface {

    augeas {
      $interface:
        context => '/files/etc/network/interfaces',
        changes => [
          "set iface[. = '${interface}'] ${interface}",
          "set iface[. = '${interface}']/family inet",
          "set iface[. = '${interface}']/method dhcp"
        ]
    }

    exec {
      "/sbin/ifup ${interface}":
        refreshonly => true;
    }

    file {
      '/etc/dhcp/dhclient-exit-hooks.d/g5k-update-host-name':
        ensure => absent;
    }

    File['/etc/dhcp/dhclient-exit-hooks.d/g5k-update-host-name'] -> Augeas['eth2']
    Augeas[$interface] ~> Exec["/sbin/ifup ${interface}"]

  }

}
