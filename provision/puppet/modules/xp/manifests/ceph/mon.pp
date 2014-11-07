class xp::ceph::mon {

  include 'xp::ceph'

  $ceph_description = hiera_hash('ceph_description')
  $mon_device = $ceph_description[$fqdn]['mon']['device']
  $fs = hiera('fs')
  $fsid = hiera('ceph_fsid')

  File <| tag == 'ceph_tree' |> {
    ensure => directory,
    mode   => '0644',
    owner  => root,
    group  => root
  }

  file {
    "${xp::ceph::path}/mon/mon_${hostname}":
      tag => 'ceph_tree';
    "${xp::ceph::path}/mon/mon_${hostname}/data":
      tag => 'ceph_tree';
    "${xp::ceph::path}/bootstrap-mon":
      tag => 'ceph_tree';
    "${xp::ceph::path}/bootstrap-mon/ceph-mon-keyring":
      ensure  => file,
      mode    => '0640',
      owner   => root,
      group   => root,
      source  => "puppet://${puppetmaster}/xpfiles/ceph.mon.keyring",
      before  => Exec['Populate the monitor daemon'],
      require => [File['/etc/ceph/ceph.client.admin.keyring'], File['/etc/ceph/ceph.conf']];
  }

  exec {
    'Populate the monitor daemon':
      command => "/usr/bin/ceph-mon --mkfs -i ${hostname} --monmap ${xp::ceph::path}/bootstrap-mon/monmap --keyring ${xp::ceph::path}/bootstrap-mon/ceph-mon-keyring",
      user    => root,
      group   => root,
      creates => "${xp::ceph::path}/mon/mon_${hostname}/data/keyring",
      require => [File["${xp::ceph::path}/mon/mon_${hostname}/data"], Exec['Generate monitor map'], File["${xp::ceph::path}/bootstrap-mon/ceph-mon-keyring"]];
  }

  unless $mon_device == 'sda' {
    exec {
      "/sbin/parted -s /dev/${mon_device} mklabel msdos":
        notify      => Exec["/sbin/parted -s /dev/${mon_device} --align optimal mkpart primary ${fs} 0 100%"],
        refreshonly => true,
        require     => Package['parted'],
        subscribe   => File["${xp::ceph::path}/mon/mon_${hostname}"];
      "/sbin/parted -s /dev/${mon_device} --align optimal mkpart primary ${fs} 0 100%":
        notify      => Exec["/sbin/mkfs.${fs} /dev/${mon_device}1"],
        refreshonly => true,
        require     => Package['parted'];
      "/sbin/mkfs.${fs} /dev/${mon_device}1":
        refreshonly => true;
    }

    mount {
      "${xp::ceph::path}/mon/mon_${hostname}":
        ensure    => mounted,
        device    => "/dev/${mon_device}1",
        fstype    => $fs,
        options   => 'rw,noexec,nodev,noatime,nodiratime,barrier=0',
        require   => Exec["/sbin/mkfs.${fs} /dev/${mon_device}1"],
        before    => File["${xp::ceph::path}/mon/mon_${hostname}/data"];
    }
  }

  service {
    "ceph-mon":
      ensure  => running,
      start   => "service ceph start mon.${hostname}",
      stop    => "service ceph stop mon.${hostname}",
      status  => "service ceph status mon.${hostname}",
      require => Exec['Populate the monitor daemon'];
  }


}
