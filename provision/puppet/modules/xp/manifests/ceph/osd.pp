class xp::ceph::osd {

  include "xp::ceph"

  File <| tag == 'ceph_tree' |> {
    ensure => directory,
    mode   => '0644',
    owner  => root,
    group  => root
  }

  $node_description = hiera_hash('node_description')
  $nodes = hiera_array('ceph_nodes')
  $osd_devices = $node_description['osd']
  $fs = hiera('filesystem')

  $node_id = get_array_id($nodes, $fqdn)

  xp::ceph::osd_tree {
    $osd_devices:
      fstype => $fs;
  }

  define xp::ceph::osd_tree($fstype) {

    $device_id = get_array_id($xp::ceph::osd::osd_devices, $name)
    $id = "${xp::ceph::osd::node_id}${device_id}"

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
    }

    mount {
      "/srv/ceph/osd_${id}":
        ensure  => mounted,
        device  => "/dev/${name}1",
        fstype  => $fstype,
        options => 'rw,noexec,nodev,noatime,nodiratime,barrier=0',
        require => Exec["/sbin/mkfs.${fstype} /dev/${name}1"];
    }

  }

}
