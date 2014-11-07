class xp::frontend::ceph {

    include '::ceph'
    include 'xp::ceph::keys'

    $monitors = hiera('ceph_monitors')
    $monitor_short = inline_template("<%= @monitors.first.split('.').first %>")

    exec {
      'Generate ceph admin key':
        command => "/usr/bin/ceph-authtool --create-keyring /etc/puppet/exports/xpfiles/ceph.client.admin.keyring --gen-key -n client.admin --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow'",
        user    => root,
        group   => root,
        creates => '/etc/puppet/exports/xpfiles/ceph.client.admin.keyring',
        tag     => 'key_generation';
      'Generate ceph radosgw key':
        command => "/usr/bin/ceph-authtool --create-keyring /etc/puppet/exports/xpfiles/ceph.client.radosgw.keyring -n client.radosgw.${monitor_short} --gen-key --cap osd 'allow rwx' --cap mon 'allow rw'",
        user    => root,
        group   => root,
        creates => '/etc/puppet/exports/xpfiles/ceph.client.radosgw.keyring',
        tag     => 'key_generation';
      'Generate ceph monitor key':
        command => "/usr/bin/ceph-authtool --create-keyring /etc/puppet/exports/xpfiles/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'",
        user    => root,
        group   => root,
        creates => '/etc/puppet/exports/xpfiles/ceph.mon.keyring',
        notify  => Exec['Add client admin key to monitor key'],
        tag     => 'key_generation';
      'Add client admin key to monitor key':
        command     => "/usr/bin/ceph-authtool /etc/puppet/exports/xpfiles/ceph.mon.keyring --import-keyring /etc/puppet/exports/xpfiles/ceph.client.admin.keyring",
        user        => root,
        group       => root,
        refreshonly => true,
        require     => Exec['Generate ceph monitor key'];
      'Generate secretfile for cephfs':
        command => '/usr/bin/ceph-authtool --name client.admin /etc/puppet/exports/xpfiles/ceph.client.admin.keyring --print-key > /etc/puppet/exports/xpfiles/secretfile',
        creates => '/etc/puppet/exports/xpfiles/secretfile',
        user    => root,
        group   => root;
    }

    File['/etc/puppet/exports/xpfiles'] -> Exec <| tag == 'key_generation' |>
    Package['ceph'] -> Exec <| tag == 'key_generation' |>

    file {
      [
        '/etc/puppet/exports/xpfiles/ceph.client.admin.keyring',
        '/etc/puppet/exports/xpfiles/ceph.client.radosgw.keyring',
        '/etc/puppet/exports/xpfiles/ceph.mon.keyring'
      ]:
        mode    => '0640',
        owner   => root,
        group   => puppet;
    }

    Exec['Generate ceph admin key'] -> File['/etc/puppet/exports/xpfiles/ceph.client.admin.keyring']
    Exec['Generate ceph radosgw key'] -> File['/etc/puppet/exports/xpfiles/ceph.client.radosgw.keyring']
    Exec['Generate ceph monitor key'] -> File['/etc/puppet/exports/xpfiles/ceph.mon.keyring']

}
