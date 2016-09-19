# Website from statically generated PHP.
define sites::apps::wordpress (
  # manage config file
  $config_filename=undef,
  $config_template=undef,

  # manage mysql database
  $mysql_manage_db=true,
  $mysql_db_name=$title,
  $mysql_db_user=regsubst($title, '(.{16}).*', '\1'),
  $mysql_db_password=fqdn_rand_string(32, '', "${::sites_seed}${name}"),
  $mysql_db_host=localhost,
  $mysql_db_init_filename=undef,

  # manage vhost
  $vhost=true,
  $web_user='www-data',

  # propagate vhost settings
  $ssl=true,
  $nowww_compliance='class_b',

  # access settings
  $whitelist=undef,
){
  # paths
  $root="${::sites::root}/${name}/"
  $webroot="${::sites::root}/${name}/html/"
  include ::cron

  # include module global php config
  include ::sites::php::fpm
  include ::sites::vhosts::map

  if $mysql_manage_db {
    if $mysql_db_init_filename {
      $schema = "${root}/${mysql_db_init_filename}"
    } else {
      $schema = "/var/backups/mysql/${name}.sql"
    }
    mysql::db { $mysql_db_name:
      user     => $mysql_db_user,
      password => $mysql_db_password,
      host     => $mysql_db_host,
      grant    => ['SELECT', 'UPDATE', 'INSERT', 'DELETE'],
      sql      => $schema,
    }
  }

  if $ssl {
    $siteurl_proto = 'https://'
  } else {
    $siteurl_proto = 'http://'
  }

  if $nowww_compliance == 'class_a' {
    $siteurl = "${siteurl_proto}www.${name}"
  } else {
    $siteurl = "${siteurl_proto}${name}"
  }

  # put db config in wp-config.php
  file_line {
    "${name}-wp-name":
      ensure => present,
      path   => "${webroot}/wp-config.php",
      line   => "define('DB_NAME', '${mysql_db_name}');",
      match  => "^define.'DB_NAME'";
    "${name}-wp-user":
      ensure => present,
      path   => "${webroot}/wp-config.php",
      line   => "define('DB_USER', '${mysql_db_user}');",
      match  => "^define.'DB_USER'";
    "${name}-wp-password":
      ensure => present,
      path   => "${webroot}/wp-config.php",
      line   => "define('DB_PASSWORD', '${mysql_db_password}');",
      match  => "^define.'DB_PASSWORD'";
    "${name}-siteurl":
      ensure => present,
      path   => "${webroot}/wp-config.php",
      line   => "define('WP_SITEURL', '${siteurl}');",
      after  => '',
      match  => "^define.'WP_SITEURL'";
  }

  Package['nginx'] ->
  php::fpm::conf { $name:
    listen               => "/var/run/php5-fpm-${name}.sock",
    user                 => $web_user,
    listen_owner         => $web_user,
    listen_group         => $web_user,
    pm_max_children      => 3,
    pm_start_servers     => 2,
    pm_min_spare_servers => 1,
    pm_max_spare_servers => 3,
  }

  nginx::resource::upstream { $name:
      members => [
          "unix:/var/run/php5-fpm-${name}.sock",
      ],
  }

  # disable caching and provide ACL for /wp-admin
  nginx::resource::location { "${name}-wp-admin":
    vhost          => $name,
    priority       => 450,
    ssl            => $ssl,
    www_root       => $webroot,
    location       => '/wp-admin/',
    location_deny  => [all],
    location_allow => $whitelist,
  }
  # disable caching and provide ACL for /wp-admin
  nginx::resource::location { "${name}-wp-admin-php":
    vhost          => $name,
    priority       => 450,
    ssl            => $ssl,
    www_root       => $webroot,
    location       => '~ ^/wp-.*\.php$',
    location_deny  => [all],
    location_allow => $whitelist,
    fastcgi        => $name,
    fastcgi_params => '/etc/nginx/fastcgi_params',
  }

  if $vhost {
    include ::sites
    sites::vhosts::php { $name:
      nowww_compliance => $nowww_compliance,
      ssl              => $ssl,
    }
  }
}
