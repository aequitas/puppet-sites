# setup generic config for nginx/php/mysql sites
class sites (
  # default vhost
  $realm=$::fqdn,
  $default_vhost_content='',

  # db related
  $manage_mysql=true,
  $mysql_root_pw=undef,
  $pma=false,
  $pma_allow=[],

  # global vhost settings
  $ssl=true,
  $ssl_secure=true,
  $root='/var/www',

  # resource hashes for hiera
  $apps_static_php={},
  $vhost_webroot={},
){
  # TODO include php module in every php subresource

  create_resources(apps::static_php, $apps_static_php, {})
  create_resources(vhosts::webroot, $vhost_webroot, {})

  # configure global letsencrypt if SSL is enabled
  if $ssl {
    class { 'letsencrypt': }

    # improve DH key for Forward secrecy
    exec { 'generate DH key':
      command => 'openssl dhparam -out dhparam.pem 4096',
      cwd     => '/etc/ssl/certs',
      creates => '/etc/ssl/certs/dhparam.pem',
    }

    $dhparam = '/etc/ssl/certs/dhparam.pem'
  } else {
    $dhparam = undef
  }

  # only offer secure ssl ciphers:
  # https://blog.qualys.com/ssllabs/2013/08/05/configuring-apache-nginx-and-openssl-for-forward-secrecy
  if $ssl_secure {
      $ssl_ciphers = 'EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS'
  } else {
      $ssl_ciphers = undef
  }

  # nginx
  Anchor['nginx::begin'] ->
  class {'nginx::config':
    # global caching settings
    fastcgi_cache_path      =>  "${root}/cache/",
    fastcgi_cache_key       =>  '"$scheme$request_method$host$request_uri"',
    fastcgi_cache_keys_zone =>  'default:250m',
    fastcgi_cache_max_size  =>  '500m',
    fastcgi_cache_inactive  =>  '30m',
    log_format              => {
      cache => '$remote_addr - $upstream_cache_status [$time_local] $request $status $body_bytes_sent $http_referer $http_user_agent',
    },
  }
  class {'nginx': }

  # bugfix: https://github.com/jfryman/puppet-nginx/issues/610
  Class['::nginx::config'] -> Nginx::Resource::Vhost <| |>
  Class['::nginx::config'] -> Nginx::Resource::Upstream <| |>

  file {
    $root:
      ensure => directory;
    "${root}/cache":
      ensure => directory,
  }

  # dbs
  if $manage_mysql {
    class { '::mysql::server':
        root_password           => $mysql_root_pw,
        remove_default_accounts => true,
    }
  }

  # default realm vhost
  sites::vhosts::webroot {$realm:
      default_vhost => true,
  }
  file { "/var/www/${realm}/html/index.html":
    content => $default_vhost_content,
  }

  if $pma {
    # phpmyadmin
    File['/var/www/phpmyadmin/html/'] ->
    class { 'phpmyadmin':
        path    => '/var/www/phpmyadmin/html/pma',
        user    => 'www-data',
        servers => [
            {
                desc => 'local',
                host => '127.0.0.1',
            },
        ],
    }
    sites::vhosts::php{ 'phpmyadmin':
        server_name    => "phpmyadmin.${realm}",
        location_allow => $pma_allow,
        location_deny  => ['all'],
    }
  }
}
