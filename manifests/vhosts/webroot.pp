# vhost just serving static content
define sites::vhosts::webroot (
  $domain=$name,
  $realm=$sites::realm,
  $webroot="/var/www/${name}/html/",
  $default_vhost=false,
  $location_allow=undef,
  $location_deny=undef,
  $subdomains=[],
  # http://no-www.org/index.php
  $nowww_compliance='class_b',
  $expires='10m',
  $static_expires='30d',
  $ssl=$::sites::ssl,
  $rewrite_to_https=$::sites::ssl,
){
  if $default_vhost {
    $server_name = '_'
    $realm_name = $realm
    $letsencrypt_name = $realm
    $listen_options = 'default_server'
    $_nowww_compliance = 'class_c'
  } else {
    $server_name = $name
    $realm_host = regsubst($server_name, '\.', '_')
    $realm_name = "${realm_host}.${realm}"
    $letsencrypt_name = $server_name
    $_nowww_compliance = $nowww_compliance
  }

  if $ssl {
    $certfile = "${::letsencrypt::cert_root}/${letsencrypt_name}/fullchain.pem"
    $keyfile = "${::letsencrypt::cert_root}/${letsencrypt_name}/privkey.pem"
  } else {
    $certfile = undef
    $keyfile = undef
  }

  # array of all server names to listen for
  $server_names = concat([], $server_name, $subdomains, $realm_name)

  # configure non-www compliancy
  # http://no-www.org/faq.php
  # www point to the same content as non-www domains
  if $_nowww_compliance == 'class_a' {
    $rewrite_www_to_non_www = false
    # add letsencrypt hostnames with www for every hostname
    $le_subdomains = concat($subdomains, prefix(concat([], $letsencrypt_name, $subdomains), 'www.'))
    $validate_domains = join($server_names, ' ')
    validate_re($validate_domains, '^(?!.*www\.).*$',
        "Class A no-www compliance specified, but www. domain specified in title or subdomains : ${validate_domains}.")
  }
  # www domains redirect to non-www domains
  if $_nowww_compliance == 'class_b' {
    $rewrite_www_to_non_www = true
    # add letsencrypt hostnames with www for every hostname
    $le_subdomains = concat($subdomains, prefix(concat([], $letsencrypt_name, $subdomains), 'www.'))
    $validate_domains = join($server_names, ' ')
    validate_re($validate_domains, '^(?!.*www\.).*$',
        "Class B no-www compliance specified, but www. domain specified in title or subdomains : ${validate_domains}.")
  }
  # www domains do not exist
  if $_nowww_compliance == 'class_c' {
    $rewrite_www_to_non_www = false
    $le_subdomains = $subdomains
    $validate_domains = join($server_names, ' ')
    validate_re($validate_domains, '^(?!.*www\.).*$',
        "Class C no-www compliance specified, but a wwww. domain in subdomains: ${validate_domains}.")
  }

  file {
    "/var/www/${name}/":
    ensure => directory,
    owner  => www-data,
    group  => www-data;
    $webroot:
    ensure => directory,
    owner  => www-data,
    group  => www-data;
  } ->
  nginx::resource::vhost { $name:
    server_name            => [$server_name, $realm_name],
    www_root               => $webroot,
    index_files            => ['index.html'],
    listen_options         => $listen_options,
    ssl                    => $ssl,
    ssl_key                => $keyfile,
    ssl_cert               => $certfile,
    rewrite_to_https       => $rewrite_to_https,
    rewrite_www_to_non_www => $rewrite_www_to_non_www,
    location_allow         => $location_allow,
    location_deny          => $location_deny,
    vhost_cfg_append       => {
      'expires' => $expires,
    }
  }

  # disable exposing php files
  nginx::resource::location { "${name}-php":
    vhost         => $name,
    ssl           => $ssl,
    www_root      => $webroot,
    location      => '~ \.php$',
    location_deny => ['all'],
  }

  # cache static files a lot
  nginx::resource::location { "${name}-static_cache":
    vhost               => $name,
    ssl                 => $ssl,
    www_root            => $webroot,
    location            => '~* \.(?:ico|css|js|gif|jpe?g|png)$',
    location_cfg_append => {
      'expires' => $static_expires,
    }
  }

  # configure letsencrypt
  if $ssl {
    letsencrypt::domain{ $letsencrypt_name:
      subdomains => $le_subdomains,
    }
    nginx::resource::location { "letsencrypt_${name}":
      location       => '/.well-known/acme-challenge',
      vhost          => $name,
      location_alias => $::letsencrypt::www_root,
      ssl            => true,
    }
  }
}
