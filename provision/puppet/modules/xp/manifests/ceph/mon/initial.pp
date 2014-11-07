class xp::ceph::mon::initial {

  include 'xp::ceph::mon'

  exec {
    'Generate monitor map':
      command => "/usr/bin/monmaptool --create --add ${hostname} ${ipaddress} --fsid ${xp::ceph::mon::fsid} ${xp::ceph::path}/bootstrap-mon/monmap",
      user    => root,
      group   => root,
      creates => "${xp::ceph::path}/bootstrap-mon/monmap",
      require => File['/etc/ceph/ceph.conf'];
  }

}
