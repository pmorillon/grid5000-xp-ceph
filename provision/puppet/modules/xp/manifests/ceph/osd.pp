class xp::ceph::osd {

  require 'xp::ceph'

  File <| tag == 'ceph_tree' |> {
    ensure => directory,
    mode   => '0644',
    owner  => root,
    group  => root
  }

  Exec {
    user    => root,
    group   => root
  }

  $node_description = hiera_hash('node_description')
  $nodes = hiera_array('ceph_nodes')
  $osd_devices = $node_description['osd']
  $fs = hiera('filesystem')

  $node_id = get_array_id($nodes, $fqdn)

  xp::ceph::osd_tree {
    $osd_devices:
      fstype  => $fs,
      require => Service['ntp'];
  }

  exec {
    "Add ceph node ${hostname} to crush map":
      command        => "/usr/bin/ceph osd crush add-bucket ${hostname} host",
      notify         => Exec["Place ceph node ${hostname} under the root default"],
      unless         => "/usr/bin/ceph osd crush dump | grep ${hostname}",
      require        => Package['ceph'];
      #      require => Xp::Ceph::Osd_tree[$osd_devices];
    "Place ceph node ${hostname} under the root default":
      command     => "/usr/bin/ceph osd crush move ${hostname} root=default",
      refreshonly => true;
  }

  define xp::ceph::osd_tree($fstype) {

    $devices = $xp::ceph::osd::osd_devices
    $device_id = get_array_id($devices, $name)
    $node_id = $xp::ceph::osd::node_id
    $id = inline_template("<%= @node_id * @devices.length + @device_id %>")

    file {
      "/srv/ceph/osd_${id}":
        tag    => 'ceph_tree',
        notify => Exec["/sbin/parted -s /dev/${name} mklabel msdos"];
    }

    exec {
      "/sbin/parted -s /dev/${name} mklabel msdos":
        notify      => Exec["/sbin/parted -s /dev/${name} --align optimal mkpart primary ${fstype} 0 100%"],
        refreshonly => true,
        require     => Package['parted'];
      "/sbin/parted -s /dev/${name} --align optimal mkpart primary ${fstype} 0 100%":
        notify      => Exec["/sbin/mkfs.${fstype} /dev/${name}1"],
        refreshonly => true,
        require     => Package['parted'];
      "/sbin/mkfs.${fstype} /dev/${name}1":
        refreshonly => true;
      "initialize osd id ${id} data directory":
        command => "/usr/bin/ceph-osd -i ${id} --mkfs --mkkey",
        creates => "/etc/ceph/keyring.osd.${id}",
        require => [File['/etc/ceph/ceph.conf'], Mount["/srv/ceph/osd_${id}"]];
      "Register the osd ${id} authentication key":
        command     => "/usr/bin/ceph auth add osd.${id} osd 'allow *' mon 'allow rwx' -i /etc/ceph/keyring.osd.${id}",
        notify      => Exec["Add the osd ${id} in the crush map"],
        refreshonly => true;
      "Add the osd ${id} in the crush map":
        command     => "/usr/bin/ceph osd crush add osd.${id} 1.0 host=${hostname}",
        refreshonly => true,
        require     => Exec["Place ceph node ${hostname} under the root default"];
    }

    File["/srv/ceph/osd_${id}"] -> Exec["initialize osd id ${id} data directory"]
    Package['ceph'] -> Exec["initialize osd id ${id} data directory"] ~> Exec["Register the osd ${id} authentication key"]

    mount {
      "/srv/ceph/osd_${id}":
        ensure  => mounted,
        device  => "/dev/${name}1",
        fstype  => $fstype,
        options => 'rw,noexec,nodev,noatime,nodiratime,barrier=0',
        require => Exec["/sbin/mkfs.${fstype} /dev/${name}1"];
    }

    service {
    "ceph-osd-${id}":
      ensure  => running,
      start   => "service ceph start osd.${id}",
      stop    => "service ceph stop osd.${id}",
      status  => "service ceph status osd.${id}",
      require => Exec["Add the osd ${id} in the crush map"];
  }


  }

}
