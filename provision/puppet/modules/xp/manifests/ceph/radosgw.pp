class xp::ceph::radosgw {

  $monitor = hiera('ceph_monitor')
  $monitor_short = inline_template("<%= @monitor.split('.').first %>")

  package {
    ['apache2', 'libapache2-mod-fastcgi', 'openssl']:
      ensure => installed;
  }

  service {
    'apache2':
      ensure => running;
  }

  apache_module {
    ['rewrite', 'fastcgi', 'ssl']:
  }

  Package['libapache2-mod-fastcgi'] -> Apache_Module['fastcgi']

  apache_site {
    'rgw.conf':
      ensure  => present,
      require => File['/etc/apache2/sites-available/rgw.conf'];
    'default':
      ensure => absent;
  }

  package {
    'radosgw':
      ensure => installed;
  }

  service {
    'radosgw':
      ensure  => running,
      require => [Package['radosgw'], File['/etc/ceph/ceph.conf']];
  }

  file {
    '/etc/ceph/ceph.client.radosgw.keyring':
      ensure  => file,
      mode    => '0600',
      owner   => root,
      group   => root,
      source  => "puppet://${puppetmaster}/xpfiles/ceph.client.radosgw.keyring",
      require => Package['ceph'],
      notify  => Exec["Add radosgw key to the Ceph Storage Cluster"];
    '/var/www/s3gw.fcgi':
      ensure  => file,
      mode    => 755,
      owner   => root,
      group   => root,
      content => template('xp/ceph/radosgw/s3gw.fcgi.erb'),
      require => Package['apache2'];
    '/etc/apache2/sites-available/rgw.conf':
      ensure  => file,
      mode    => '0644',
      owner   => root,
      group   => root,
      content => template('xp/ceph/radosgw/apache/rgw.conf.erb'),
      require => Package['apache2'];
    '/etc/apache2/ssl':
      ensure  => directory,
      mode    => '0755',
      owner   => root,
      group   => root,
      require => Package['apache2'];
  }

  file {
    "${xp::ceph::path}/radosgw":
      ensure => directory;
    "${xp::ceph::path}/radosgw/ceph-radosgw.gateway":
      ensure => directory;
  }

  exec {
    'Add radosgw key to the Ceph Storage Cluster':
      command     => "/usr/bin/ceph -k /etc/ceph/ceph.client.admin.keyring auth add client.radosgw.${monitor_short} -i /etc/ceph/ceph.client.radosgw.keyring",
      refreshonly => true;
    'Generate apache certs':
      command => "/usr/bin/openssl req -new -x509 -days 365 -nodes -out /etc/apache2/ssl/apache.crt -keyout /etc/apache2/ssl/apache.key \
      -subj \"/C=FR/ST=/O=/localityName=Rennes/commonName=/organizationalUnitName=/emailAddress=toto@inria.fr/\"",
      creates => '/etc/apache2/ssl/apache.key',
      require => File['/etc/apache2/ssl'],
      notify  => Service['apache2'];
  }

  #File['/etc/apache2/ssl'] -> Exec['Generate apache certs']
  #Package['openssl'] -> Exec['Generate apache certs']

  define apache_module () {
    exec {
      "Enable apache module ${name}":
        command => "/usr/sbin/a2enmod $name",
        unless => "/bin/ls /etc/apache2/mods-enabled | grep '$name'",
        before => Service["apache2"],
        notify => Service["apache2"],
        require => Package["apache2"];
    }
  }

  define apache_site ($ensure) {
    case $ensure {
      present: {
        exec {
          "enable site $name":
            command => "/usr/sbin/a2ensite $name",
            unless => "/usr/bin/test -f /etc/apache2/sites-enabled/'$name'",
            notify => Service["apache2"],
            require => Package["apache2"];
        }
      }
      absent: {
        exec {
          "disable site $name":
            command => "/usr/sbin/a2dissite $name",
            onlyif => "/usr/bin/test -f /etc/apache2/sites-enabled/'$name'",
            notify => Service["apache2"],
            require => Package["apache2"];
        }
      }
      default: {
        fail "Invalid 'ensure' value '$ensure' for apache2::site"
      }
    }
  }

}
