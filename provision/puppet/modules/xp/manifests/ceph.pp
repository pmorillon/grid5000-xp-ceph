class xp::ceph {

  include '::ceph'

  package {
    'xfsprogs':
      ensure => installed;
  }

}
