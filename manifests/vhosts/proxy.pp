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
){
  nginx::resource::upstream { $name:
    members => [$proxy]
  }

  Nginx::Resource::Vhost {
    proxy => "http://${proxy}",
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
    root             => $root,
  }
}
