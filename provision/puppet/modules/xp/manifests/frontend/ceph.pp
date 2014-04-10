class xp::frontend::ceph {

    include '::ceph'
    include 'xp::ceph::keys'

    exec {
      'Generate ceph admin key':
        command => "/usr/bin/ceph-authtool --create-keyring /etc/puppet/exports/xpfiles/ceph.client.admin.keyring --gen-key -n client.admin --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow'",
        user    => root,
        group   => root,
        creates => '/etc/puppet/exports/xpfiles/ceph.client.admin.keyring',
        require => Package['ceph'];
      'Generate secretfile for cephfs':
        command => '/usr/bin/ceph-authtool --name client.admin /etc/puppet/exports/xpfiles/ceph.client.admin.keyring --print-key > /etc/puppet/exports/xpfiles/secretfile',
        creates => '/etc/puppet/exports/xpfiles/secretfile',
        user    => root,
        group   => root,
        require => Package['ceph'];
    }

    File['/etc/puppet/exports/xpfiles'] -> Exec['Generate ceph admin key']
    Package['ceph'] -> Exec['Generate ceph admin key']

    file {
      '/etc/puppet/exports/xpfiles/ceph.client.admin.keyring':
        mode  => '0640',
        owner => root,
        group => puppet;
    }

    Exec['Generate ceph admin key'] -> File['/etc/puppet/exports/xpfiles/ceph.client.admin.keyring']

}
