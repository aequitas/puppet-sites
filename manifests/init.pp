# setup generic config for nginx/php/mysql sites
class sites (
  ## default vhost
  $realm=$::fqdn,
  $default_vhost_content='',

  ## db related
  $manage_mysql=true,
  $mysql_backuprotate=2,
  $pma=false,
  $pma_allow=[],

  ## global vhost settings
  # enable ssl
  $ssl=true,
  # use more secure/less backward compatible ssl settings
  $ssl_secure=true,
  $root='/var/www',
  $dh_keysize=2048,

  # optional DNS resolver(s) to be used for proxy lookups
  $resolver=undef,

  ## resource hashes for hiera
  $apps_static_php={},
  $apps_wordpress={},

  $vhost_webroot={},
  $vhost_proxy={},

  # whether to respond to any other requests other then for explicitly declared vhosts
  $default_host=false,
){
  # TODO include php module in every php subresource

  create_resources(apps::static_php, $apps_static_php, {})
  create_resources(apps::wordpress, $apps_wordpress, {})

  create_resources(vhosts::webroot, $vhost_webroot, {})
  create_resources(vhosts::proxy, $vhost_proxy, {})

  # configure global letsencrypt if SSL is enabled
  if $ssl {
    class { 'letsencrypt': }
  }

  # only offer secure ssl ciphers:
  # https://blog.qualys.com/ssllabs/2013/08/05/configuring-apache-nginx-and-openssl-for-forward-secrecy
  if $ssl_secure {
      $ssl_ciphers = 'EECDH+ECDSA+AESGCM:EECDH+aRSA+AESGCM:EECDH+ECDSA+SHA384:EECDH+ECDSA+SHA256:EECDH+aRSA+SHA384:EECDH+aRSA+SHA256:EECDH+aRSA+RC4:EECDH:EDH+aRSA:!RC4:!aNULL:!eNULL:!LOW:!3DES:!MD5:!EXP:!PSK:!SRP:!DSS:!MEDIUM'

      # improve DH key for Forward secrecy
      exec { 'generate DH key':
        command => "/usr/bin/openssl dhparam -out dh${dh_keysize}.pem ${dh_keysize}",
        cwd     => '/etc/nginx/',
        creates => "/etc/nginx/dh${dh_keysize}.pem",
      }

      $ssl_dhparam = "/etc/nginx/dh${dh_keysize}.pem"
  } else {
    # offer default configuration of compatible ciphers
    $ssl_ciphers = undef
    $ssl_dhparam = undef
  }

  # nginx
  class {'nginx':
    package_ensure          => latest,
    # global caching settings
    fastcgi_cache_path      => "${root}/cache/",
    fastcgi_cache_key       => '"$scheme$request_method$host$request_uri"',
    fastcgi_cache_keys_zone => 'default:250m',
    fastcgi_cache_max_size  => '500m',
    fastcgi_cache_inactive  => '30m',
    fastcgi_cache_use_stale => updating,
    names_hash_bucket_size  => 80,
    http_cfg_append         => {
      fastcgi_cache_lock => on,
    },
    log_format              => {
      cache => '$remote_addr - $upstream_cache_status [$time_local] $request $status $body_bytes_sent $http_referer $http_user_agent',
    },
    # enable compression on all responses
    gzip_proxied            => any,
    gzip_types              => '*',
    gzip_vary               => on,
    # enable http/2 support
    http2                   => on,
    # remove unmanaged resources
    server_purge            => true,
    confd_purge             => true,
  }

  file {
    $root:
      ensure => directory;
    "${root}/cache":
      ensure => directory,
  }

  $random_seed = file('/var/lib/puppet/.random_seed')

  # dbs
  if $manage_mysql {
    class { '::mysql::server':
      # a random password is generated for mysql root (and backup)
      # to login as mysql root use `mysql` as root user or sudo `sudo -i mysql`
      root_password           => fqdn_rand_string(32, '', "${random_seed}mysql_root"),
      remove_default_accounts => true,
    }
    class { '::mysql::server::backup':
      backupuser        => backup,
      backuppassword    => fqdn_rand_string(32, '', "${random_seed}mysql_backup"),
      backupdir         => '/var/backups/mysql/',
      file_per_database => true,
      backuprotate      => $mysql_backuprotate,
    }

    # generate timezone information and load into mysql
    package {'tzdata': } ->
    Class['mysql::server'] ->
    exec { 'generate mysql timezone info sql':
      command => '/usr/bin/mysql_tzinfo_to_sql /usr/share/zoneinfo > /var/lib/mysql/tzinfo.sql',
      creates => '/var/lib/mysql/tzinfo.sql',
    } ~>
    exec { 'import mysql timezone info sql':
      command     => '/usr/bin/mysql  --defaults-file=/root/.my.cnf mysql < /var/lib/mysql/tzinfo.sql',
      refreshonly => true,
    }
  }

  if $default_host {
    # default realm vhost
    sites::vhosts::vhost {$realm:
        default_vhost    => true,
        nowww_compliance => 'class_c',
        rewrite_to_https => false,
    }
    file { "/var/www/${realm}/html/index.html":
      content => $default_vhost_content,
    }
  } else {
    # deny requests on default vhost with an empty response
    sites::vhosts::disabled {$realm:
      default_vhost    => true,
      nowww_compliance => 'class_c',
    }
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
