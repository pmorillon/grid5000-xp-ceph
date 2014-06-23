class ceph::apt (
  $version = 'emperor'
) {

  $key = '17ED316D'

  exec {
    'import_ceph_apt_key':
      command     => "/usr/bin/wget -q 'http://ceph.com/git/?p=ceph.git;a=blob_plain;f=keys/release.asc' -O- | apt-key add -",
      environment => "http_proxy=http://proxy:3128",
      unless      => "/usr/bin/apt-key list | /bin/grep '${key}'";
    '/usr/bin/apt-get update':
      refreshonly => true;
  }

  file {
    '/etc/apt/sources.list.d/ceph.list':
      ensure  => file,
      mode    => '0644',
      owner   => root,
      group   => root,
      content => "# ceph
deb http://ceph.com/debian-${version}/ ${::lsbdistcodename} main
deb-src http://ceph.com/debian-${version}/ ${::lsbdistcodename} main";
  }

  Exec['import_ceph_apt_key'] -> File['/etc/apt/sources.list.d/ceph.list'] ~> Exec['/usr/bin/apt-get update']

}
