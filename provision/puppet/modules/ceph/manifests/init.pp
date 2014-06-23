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

  Class['ceph::apt'] -> Package['ceph']

}
