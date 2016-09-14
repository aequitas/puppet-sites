# install and manage php fpm daemon
class sites::php::fpm {
  # include module global php config
  include ::sites::php

  # install and manage daemon
  include ::php::fpm::daemon

  # disable default pool
  php::fpm::conf { 'www': ensure => absent }

  # load settings from hiera
  create_resources('php::fpm::conf', hiera_hash('php::fpm::config', {}))
}
