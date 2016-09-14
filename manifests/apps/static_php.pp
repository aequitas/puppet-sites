# Website from statically generated PHP.
define sites::apps::static_php (
  $git_source=undef,

  $config_filename=undef,
  $config_template=undef,

  # manage mysql database
  $mysql_manage_db=true,
  $mysql_db_name=$title,
  $mysql_db_user=$title,
  $mysql_db_password=$title,
  $mysql_db_host=localhost,
  $mysql_db_init_filename=undef,

  # manage vhost
  $vhost=true,
  $web_user='www-data',
){
  $root = "/var/www/${title}"
  $webroot = "${root}/html"

  ensure_packages(['php5-cli'], {'ensure' => 'present'})

  if $git_source {
    ensure_packages(['git'], {'ensure' => 'present'})

    vcsrepo { $root:
      ensure   => latest,
      provider => git,
      source   => $git_source,
      revision => master,
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
      grant    => ['SELECT', 'UPDATE', 'INSERT', 'DELETE'],
      sql      => $schema,
    } -> Exec["${title} generate"]
  }

  file { "${root}/generate.sh":
    content => "cd ${webroot}/; timeout 600 /usr/bin/php index.php > index.html_;mv index.html_ index.html\n",
    mode    => '0755',
    owner   => $web_user,
    group   => $web_user,
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
