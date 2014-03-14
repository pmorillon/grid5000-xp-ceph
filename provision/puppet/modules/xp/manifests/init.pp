class xp {

  stage {
    'setup':
      before => Stage['main'];
  }

  class {
    'apt':
      proxy_host => 'proxy',
      proxy_port => '3128',
      stage      => 'setup';
  }

}

