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

){
  # TODO include php module in every php subresource

  create_resources(apps::static_php, $apps_static_php, {})

  # only offer secure ssl ciphers: https://gist.github.com/gavinhungry/7a67174c18085f4a23eb
  if $ssl_secure {
      $ssl_ciphers = 'EECDH+ECDSA+AESGCM:EECDH+aRSA+AESGCM:EECDH+ECDSA+SHA512:EECDH+ECDSA+SHA384:EECDH+ECDSA+SHA256:ECDH+AESGCM:ECDH+AES256:DH+AESGCM:DH+AES256:RSA+AESGCM:!aNULL:!eNULL:!LOW:!RC4:!3DES:!MD5:!EXP:!PSK:!SRP:!DSS'
  } else {
      $ssl_ciphers = undef
  }

  # nginx
  Anchor['nginx::begin'] -> class {'nginx::config':
    # global caching settings
    fastcgi_cache_path      =>  "${root}/cache",
    fastcgi_cache_key       =>  '"$scheme$request_method$host$request_uri"',
    fastcgi_cache_keys_zone =>  'default:250m',
    fastcgi_cache_max_size  =>  '500m',
    fastcgi_cache_inactive  =>  '30m',
    log_format              => {
      cache => '$remote_addr - $upstream_cache_status [$time_local] $request $status $body_bytes_sent $http_referer $http_user_agent',
    },
    # global ssl settings
    ssl_ciphers             => $ssl_ciphers,
  }
  class {'nginx': }

  file {
    $root:
      ensure => directory;
    "${root}/cache":
      ensure => directory,
  }

  # configure global letsencrypt if SSL is enabled
  if $ssl {
    class { 'letsencrypt': }
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
