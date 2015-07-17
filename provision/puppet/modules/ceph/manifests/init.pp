class ceph (
  $version = 'firefly'
) {

  class {
    '::ceph::apt':
      version => $version;
  }

  package {
    'ceph':
      ensure => installed;
  }

  Class['ceph::apt'] -> Package['ceph']

}
