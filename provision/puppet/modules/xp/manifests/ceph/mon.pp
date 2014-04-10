class xp::ceph::mon {

  include "xp::ceph"

  $node_description = hiera_hash('node_description')
  $mon_device = $node_description['mon']
  $fs = hiera('filesystem')
  $fsid = hiera('ceph_fsid')

  File <| tag == 'ceph_tree' |> {
    ensure => directory,
    mode   => '0644',
    owner  => root,
    group  => root
  }

  file {
    "/srv/ceph/mon_${hostname}":
      tag    => 'ceph_tree';
    "/srv/ceph/mon_${hostname}/data":
      tag     => 'ceph_tree';
    '/etc/ceph/ceph.client.admin.keyring':
      ensure  => file,
      mode    => '0600',
      owner   => root,
      group   => root,
      source  => "puppet://${puppetmaster}/xpfiles/ceph.client.admin.keyring",
      require => Package['ceph'];
  }

  exec {
    'Generate monitor secret key':
      command => "/usr/bin/ceph-authtool --create-keyring /tmp/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'",
      user    => root,
      group   => root,
      creates => '/tmp/ceph.mon.keyring',
      notify  => Exec['Add client admin key to monitor key'],
      require => [File['/etc/ceph/ceph.client.admin.keyring'], File['/etc/ceph/ceph.conf']];
    'Add client admin key to monitor key':
      command     => "/usr/bin/ceph-authtool /tmp/ceph.mon.keyring --import-keyring /etc/ceph/ceph.client.admin.keyring",
      user        => root,
      group       => root,
      refreshonly => true,
      before      => Exec['Populate the monitor daemon'],
      require     => File['/etc/ceph/ceph.client.admin.keyring'];
    'Generate monitor map':
      command => "/usr/bin/monmaptool --create --add ${hostname} ${ipaddress} --fsid ${fsid} /tmp/monmap",
      user    => root,
      group   => root,
      creates => '/tmp/monmap',
      require => File['/etc/ceph/ceph.conf'];
    'Populate the monitor daemon':
      command => "/usr/bin/ceph-mon --mkfs -i ${hostname} --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring",
      user    => root,
      group   => root,
      creates => "/srv/ceph/mon_${hostname}/data/keyring",
      require => [File["/srv/ceph/mon_${hostname}/data"], Exec['Generate monitor map'], Exec['Generate monitor secret key']];
  }

  unless $mon_device == 'sda' {
    exec {
      "/sbin/parted -s /dev/${mon_device} mklabel msdos":
        notify      => Exec["/sbin/parted -s /dev/${mon_device} --align optimal mkpart primary ${fs} 0 100%"],
        refreshonly => true,
        require     => Package['parted'],
        subscribe   => File["/srv/ceph/mon_${hostname}"];
      "/sbin/parted -s /dev/${mon_device} --align optimal mkpart primary ${fs} 0 100%":
        notify      => Exec["/sbin/mkfs.${fs} /dev/${mon_device}1"],
        refreshonly => true,
        require     => Package['parted'];
      "/sbin/mkfs.${fs} /dev/${mon_device}1":
        refreshonly => true;
    }

    mount {
      "/srv/ceph/mon_${hostname}":
        ensure    => mounted,
        device    => "/dev/${mon_device}1",
        fstype    => $fs,
        options   => 'rw,noexec,nodev,noatime,nodiratime,barrier=0',
        require   => Exec["/sbin/mkfs.${fs} /dev/${mon_device}1"],
        before    => File["/srv/ceph/mon_${hostname}/data"];
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
