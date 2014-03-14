class ceph {

  include 'ceph::apt'

  package {
    'ceph':
      ensure => installed;
    'xfsprogs':
      ensure => installed;
  }

  Apt::Source['ceph'] -> Package['ceph']

}
