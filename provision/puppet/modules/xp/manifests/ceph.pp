class xp::ceph {

  include '::ceph'
  include 'xp::ceph::osd'
  include 'xp::ceph::mon'

  package {
    ['xfsprogs', 'parted']:
      ensure => installed;
  }

  file {
    '/srv/ceph':
      tag    => 'ceph_tree';
  }

}
