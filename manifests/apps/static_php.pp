# Website from statically generated PHP.
define sites::apps::static_php (
  # manage wwwroot contect from git repository
  $git_source=undef,
  $git_revision=master,

  # manage config file
  $config_filename=undef,
  $config_template=undef,

  # manage mysql database
  $mysql_manage_db=true,
  $mysql_db_name=$title,
  $mysql_db_user=$title,
  $mysql_db_password=$title,
  $mysql_db_host=localhost,
  $mysql_db_init_filename=undef,
  $mysql_access=write,

  # manage vhost
  $vhost=true,
  $web_user='www-data',
){
  # paths
  $root="${::sites::root}/${name}"
  $webroot="${::sites::root}/${name}/html"
  $logroot="${::sites::root}/${name}/logs"

  include ::cron

  # include module global php config
  include ::sites::php::cli

  if $git_source {
    ensure_packages(['git'], {'ensure' => 'present'})

    vcsrepo { $root:
      ensure   => latest,
      provider => git,
      source   => $git_source,
      revision => $git_revision,
      owner    => $web_user,
      group    => $web_user,
    }
  }

  if $config_filename and $config_template {
    file { "${root}/${config_filename}":
      owner   => $web_user,
      group   => $web_user,
      content => inline_template($config_template),
    } ~> Exec["${title} generate"]
  }

  # configure mysql permissions based on access level
  $mysql_grant = $mysql_access ? {
    write => ['SELECT', 'UPDATE', 'INSERT', 'DELETE'],
    read  => ['SELECT'],
  }

  if $mysql_manage_db {
    if $mysql_db_init_filename {
      $schema = "${root}/${mysql_db_init_filename}"
    } else {
      $schema = "/var/backups/mysql/${title}.sql"
    }

    mysql::db { $mysql_db_name:
      user     => $mysql_db_user,
      password => $mysql_db_password,
      host     => $mysql_db_host,
      grant    => $mysql_grant,
      sql      => $schema,
    } -> Exec["${title} generate"]
  } else {
    mysql_user { "${mysql_db_user}@${mysql_db_host}":
      password => $mysql_db_password,
    }
    mysql_grant { "${mysql_db_user}@${mysql_db_host}":
      privileges => $mysql_grant,
    }
  }

  file { "${root}/generate.sh":
    content => template('sites/generate.sh.erb'),
    mode    => '0755',
    owner   => $web_user,
    group   => $web_user,
  }

  file { $logroot:
    ensure => directory,
    mode   => '0755',
    owner  => $web_user,
    group  => $web_user,
  }

  logrotate::rule { "static_php_${title}":
    path         => $logroot,
    compress     => true,
    rotate       => 5,
    rotate_every => 'week',
  }

  # generate index.html for index.php file every 10 minutes.
  cron { "${title}-static-generation":
    command => "${root}/generate.sh",
    minute  => '*/10',
    user    => $web_user,
  }

  exec { "${title} generate":
    command => "${root}/generate.sh",
    creates => "${webroot}/index.html",
    user    => $web_user,
    require => [
      Package['php5-cli'],
      File["${root}/generate.sh"]
    ]
  }

  if $vhost {
    include ::sites
    sites::vhosts::webroot { $title: }
  }
}
