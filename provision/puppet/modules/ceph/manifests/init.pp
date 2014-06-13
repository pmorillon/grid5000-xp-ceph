class ceph (
  $version = 'emperor'
) {

  class {
    'ceph::apt':
      version => $version;
  }

  package {
    'ceph':
      ensure => installed;
  }

  Apt::Source['ceph'] -> Package['ceph']

}
