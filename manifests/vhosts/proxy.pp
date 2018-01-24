# generic vhost serving static content under webroot
# supports subdomains, ssl, ipv6, caching and no-www
define sites::vhosts::proxy (
  # proxy settings
  $proxy=undef,

  # domain name settings
  $domain=$name,
  $realm=$sites::realm,
  $default_vhost=false,
  # additional subdomains (no www.)
  $subdomains=[],
  # http://web.archive.org/web/20101230024259/http://no-www.org:80/index.php
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
  $resolver=$::sites::resolver,
  # optional unproxied path to webroot for static files
  $webroot=undef,
  # configure client certificate authentication using this CA
  $client_ca=undef,
  $caching=undef
){
  sites::vhosts::vhost { $name:
    domain              => $domain,
    realm               => $realm,
    default_vhost       => $default_vhost,
    subdomains          => $subdomains,
    nowww_compliance    => $nowww_compliance,
    ipv6                => $ipv6,
    ssl                 => $ssl,
    rewrite_to_https    => $rewrite_to_https,
    ssl_ciphers         => $ssl_ciphers,
    ssl_dhparam         => $ssl_dhparam,
    expires             => $expires,
    static_expires      => $static_expires,
    location_allow      => $location_allow,
    location_deny       => $location_deny,
    root                => $root,
    # use variable for proxy destination icw resolver, this won't cause
    # nginx to fail if the address is unresolvable during start
    proxy               => "\$backend",
    resolver            => $resolver,
    location_cfg_append => {
      'set $backend' => "http://${proxy}",
    },
    client_ca           => $client_ca,
    caching             => $caching
  }

  if $webroot {
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
}
