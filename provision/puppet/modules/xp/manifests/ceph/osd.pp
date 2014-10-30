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

  $ceph_description = hiera_hash('ceph_description')
  $nodes = hiera_array('ceph_nodes')
  $osd_desc = $ceph_description[$fqdn]['osd']

  exec {
    "Add ceph node ${hostname} to crush map":
      command        => "/usr/bin/ceph osd crush add-bucket ${hostname} host",
      notify         => Exec["Place ceph node ${hostname} under the root default"],
      unless         => "/usr/bin/ceph osd crush dump | grep ${hostname}",
      require        => Package['ceph'],
      before         => Xp::Ceph::Osd_tree['osd_tree'];
    "Place ceph node ${hostname} under the root default":
      command     => "/usr/bin/ceph osd crush move ${hostname} root=default",
      refreshonly => true;
  }

  xp::ceph::osd_tree {
    'osd_tree':
  }

  define xp::ceph::osd_tree() {

    each($xp::ceph::osd::osd_desc) |$x| {

      $device = $x['device']
      $id = $x['id']
      $fs = $x['fs']

      $partition = $device ? {
        'sda'   => 5,
        default => 1
      }

      file {
        "${xp::ceph::path}/osd/osd_$id":
          tag    => 'ceph_tree',
          notify => $device ? {
            'sda'   => Exec["/sbin/mkfs.${fs} /dev/${device}${partition}"],
            default => Exec["/sbin/parted -s /dev/${device} mklabel msdos"]
          };
        #      "${xp::ceph::path}/osd/osd_${id}/keyring":
        #ensure  => file,
        #require => Mount["${xp::ceph::path}/osd/osd_${id}"];
        }

        exec {
          "/sbin/parted -s /dev/${device} mklabel msdos":
            notify      => Exec["/sbin/parted -s /dev/${device} --align optimal mkpart primary ${fs} 0 100%"],
            refreshonly => true,
            require     => Package['parted'];
          "/sbin/parted -s /dev/${device} --align optimal mkpart primary ${fs} 0 100%":
            notify      => Exec["/sbin/mkfs.${fs} /dev/${device}${partition}"],
            refreshonly => true,
            require     => Package['parted'];
          "/sbin/mkfs.${fs} /dev/${device}${partition}":
            refreshonly => true;
          "initialize osd id ${id} data directory":
            command => "/usr/bin/ceph-osd -i ${id} --mkfs --mkkey",
            creates => "${xp::ceph::path}/osd/osd_${id}/keyring",
            require => [File['/etc/ceph/ceph.conf'], Mount["${xp::ceph::path}/osd/osd_${id}"]];
          "Register the osd ${id} authentication key":
            command     => "/usr/bin/ceph auth add osd.${id} osd 'allow *' mon 'allow rwx' -i ${xp::ceph::path}/osd/osd_${id}/keyring",
            notify      => Exec["Add the osd ${id} in the crush map"],
            require     => File["${xp::ceph::path}/osd/osd_${id}"],
            refreshonly => true;
          "Add the osd ${id} in the crush map":
            command     => "/usr/bin/ceph osd crush add osd.${id} 1.0 host=${hostname}",
            refreshonly => true,
            require     => Exec["Place ceph node ${hostname} under the root default"];
        }

        File["${xp::ceph::path}/osd/osd_${id}"] -> Exec["initialize osd id ${id} data directory"]
        Package['ceph'] -> Exec["initialize osd id ${id} data directory"] ~> Exec["Register the osd ${id} authentication key"]

        if ($device == 'sda') {
          mount {
            "/tmp":
              ensure  => unmounted,
              before  => [Mount["${xp::ceph::path}/osd/osd_${id}"],Exec["/sbin/mkfs.${fs} /dev/${device}${partition}"]];
          }
        }

        mount {
          "${xp::ceph::path}/osd/osd_${id}":
            ensure  => mounted,
            device  => "/dev/${device}${partition}",
            fstype  => $fs,
            options => $fs ? {
              'ext4' => 'user_xattr,rw,noexec,nodev,noatime,nodiratime,barrier=0',
              'xfs'  => 'rw,noexec,nodev,noatime,nodiratime,barrier=0'
            },
            require => Exec["/sbin/mkfs.${fs} /dev/${device}${partition}"];
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

}
