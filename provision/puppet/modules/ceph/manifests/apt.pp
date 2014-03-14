class ceph::apt (
  $version = 'emperor'
) {

  apt::key {
    'ceph':
      key        => '17ED316D',
      key_source => 'http://ceph.com/git/?p=ceph.git;a=blob_plain;f=keys/release.asc',
  }

  apt::source {
    'ceph':
      location => "http://ceph.com/debian-${version}/",
      release  => $::lsbdistcodename;
  }

  Apt::Key['ceph'] -> Apt::Source['ceph']

}
