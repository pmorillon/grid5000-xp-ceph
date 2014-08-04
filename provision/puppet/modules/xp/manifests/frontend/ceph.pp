class xp::frontend::ceph {

    include '::ceph'
    include 'xp::ceph::keys'

    $monitor = hiera('ceph_monitor')
    $monitor_short = inline_template("<%= @monitor.split('.').first %>")

    exec {
      'Generate ceph admin key':
        command => "/usr/bin/ceph-authtool --create-keyring /etc/puppet/exports/xpfiles/ceph.client.admin.keyring --gen-key -n client.admin --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow'",
        user    => root,
        group   => root,
        creates => '/etc/puppet/exports/xpfiles/ceph.client.admin.keyring',
        tag     => 'key_generation',
        require => Package['ceph'];
      'Generate ceph radosgw key':
        command => "/usr/bin/ceph-authtool --create-keyring /etc/puppet/exports/xpfiles/ceph.client.radosgw.keyring -n client.radosgw.${monitor_short} --gen-key --cap osd 'allow rwx' --cap mon 'allow rw'",
        user    => root,
        group   => root,
        creates => '/etc/puppet/exports/xpfiles/ceph.client.radosgw.keyring',
        tag     => 'key_generation',
        require => Package['ceph'];
      'Generate secretfile for cephfs':
        command => '/usr/bin/ceph-authtool --name client.admin /etc/puppet/exports/xpfiles/ceph.client.admin.keyring --print-key > /etc/puppet/exports/xpfiles/secretfile',
        creates => '/etc/puppet/exports/xpfiles/secretfile',
        user    => root,
        group   => root,
        require => Package['ceph'];
    }

    File['/etc/puppet/exports/xpfiles'] -> Exec <| tag == 'key_generation' |>
    Package['ceph'] -> Exec <| tag == 'key_generation' |>

    file {
      [
        '/etc/puppet/exports/xpfiles/ceph.client.admin.keyring',
        '/etc/puppet/exports/xpfiles/ceph.client.radosgw.keyring'
      ]:
        mode  => '0640',
        owner => root,
        group => puppet;
    }

    Exec['Generate ceph admin key'] -> File['/etc/puppet/exports/xpfiles/ceph.client.admin.keyring']
    Exec['Generate ceph radosgw key'] -> File['/etc/puppet/exports/xpfiles/ceph.client.radosgw.keyring']

}
