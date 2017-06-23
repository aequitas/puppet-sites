# generic vhost serving static content under webroot
# supports subdomains, ssl, ipv6, caching and no-www
define sites::vhosts::webroot (
  # domain name settings
  $domain=$name,
  $realm=$sites::realm,
  $default_vhost=false,
  # additional subdomains (no www.)
  $subdomains=[],
  # http://no-www.org/index.php
  $nowww_compliance='class_b',
  # connection settings
  $ipv6=true,
  # SSL settings
  $ssl=$::sites::ssl,
  $rewrite_to_https=$::sites::ssl,
  $ssl_ciphers=$::sites::ssl_ciphers,
  $ssl_dhparam=$::sites::ssl_dhparam,
  # cache settings
  $expires='10m',
  $static_expires='30d',
  # access settings
  $location_allow=undef,
  $location_deny=undef,
  # paths
  $root="${::sites::root}/${name}/",
  $webroot="${::sites::root}/${name}/html/",
){
  file {
    $webroot:
      ensure => directory,
      owner  => www-data,
      group  => www-data;
  }

  Nginx::Resource::Server {
    www_root => $webroot,
    index_files => ['index.html', 'index.htm'],
  }

  vhost { $name:
    domain           => $domain,
    realm            => $realm,
    default_vhost    => $default_vhost,
    subdomains       => $subdomains,
    nowww_compliance => $nowww_compliance,
    ipv6             => $ipv6,
    ssl              => $ssl,
    rewrite_to_https => $rewrite_to_https,
    ssl_ciphers      => $ssl_ciphers,
    ssl_dhparam      => $ssl_dhparam,
    expires          => $expires,
    static_expires   => $static_expires,
    location_allow   => $location_allow,
    location_deny    => $location_deny,
  }

  # disable exposing php files
  nginx::resource::location { "${name}-php":
    server        => $name,
    ssl           => $ssl,
    ssl_only      => $rewrite_to_https,
    www_root      => $webroot,
    location      => '~ \.php$',
    location_deny => ['all'],
  }

  # cache static files a lot
  nginx::resource::location { "${name}-static_cache":
    server              => $name,
    ssl                 => $ssl,
    ssl_only            => $rewrite_to_https,
    www_root            => $webroot,
    location            => '~* \.(?:ico|css|js|gif|jpe?g|png)$',
    location_cfg_append => {
      'expires' => $static_expires,
    },
  }
}
