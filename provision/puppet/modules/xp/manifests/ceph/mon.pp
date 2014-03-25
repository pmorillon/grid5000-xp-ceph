class xp::ceph::mon {

  include "xp::ceph"

  $node_description = hiera_hash('node_description')
  $mon_device = $node_description['mon']
  $fs = hiera('filesystem')

  File <| tag == 'ceph_tree' |> {
    ensure => directory,
    mode   => '0644',
    owner  => root,
    group  => root
  }

  file {
    "/srv/ceph/mon_${hostname}":
      tag    => 'ceph_tree',
      notify => Exec["/sbin/parted -s /dev/${mon_device} mklabel msdos"];
  }

  unless $mon_device == 'sda' {
    exec {
      "/sbin/parted -s /dev/${mon_device} mklabel msdos":
        notify      => Exec["/sbin/parted -s /dev/${mon_device} --align optimal mkpart primary ${fs} 0 100%"],
        refreshonly => true,
        require     => Package['parted'];
      "/sbin/parted -s /dev/${mon_device} --align optimal mkpart primary ${fs} 0 100%":
        notify      => Exec["/sbin/mkfs.${fs} /dev/${mon_device}1"],
        refreshonly => true,
        require     => Package['parted'];
      "/sbin/mkfs.${fs} /dev/${mon_device}1":
        refreshonly => true;
    }

    mount {
      "/srv/ceph/mon_${hostname}":
        ensure  => mounted,
        device  => "/dev/${mon_device}1",
        fstype  => $fs,
        options => 'rw,noexec,nodev,noatime,nodiratime,barrier=0',
        require => Exec["/sbin/mkfs.${fs} /dev/${mon_device}1"];
    }
  }


}
