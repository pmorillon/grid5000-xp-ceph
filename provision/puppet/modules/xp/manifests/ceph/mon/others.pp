class xp::ceph::mon::others {

  include 'xp::ceph::mon'

  exec {
    'Generate monitor map':
      command => "/usr/bin/ceph mon getmap -o ${xp::ceph::path}/bootstrap-mon/monmap",
      user    => root,
      group   => root,
      creates => "${xp::ceph::path}/bootstrap-mon/monmap",
      require => File['/etc/ceph/ceph.conf'];
    'Add monitor':
      command => "/usr/bin/ceph mon add ${hostname} ${ipaddress} & sleep 5 && service ceph start mon.${hostname}",
      user    => root,
      require => Exec['Populate the monitor daemon'];
  }

}
