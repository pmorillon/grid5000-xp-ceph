class ceph {

  include 'ceph::apt'

  package {
    'ceph':
      ensure => installed;
  }

  Apt::Source['ceph'] -> Package['ceph']

}
