# vhost that return empty/no response
define sites::vhosts::disabled (
  # domain name settings
  $domain=$name,
  $realm=$sites::realm,
  $default_vhost=false,
  # additional subdomains (no www.)
  $subdomains=[],
  # http://web.archive.org/web/20101230024259/http://no-www.org:80/index.php
  Pattern[/^class_[abc]$/]
    $nowww_compliance='class_b',
  # connection settings
  $ipv6=true,
  # SSL settings
  $ssl=$::sites::ssl,
  $rewrite_to_https=$::sites::ssl,
  $ssl_ciphers=$::sites::ssl_ciphers,
  $ssl_dhparam=$::sites::ssl_dhparam,
){
  if $default_vhost {
    $server_name = '_'
    $letsencrypt_name = $realm

    $realm_name = $realm

    $listen_options = 'default_server'
    $ipv6_listen_options = 'default_server'

    if $nowww_compliance != 'class_c' {
      fail('realm must have Class C nowww compliance')
    }
  } else {
    $server_name = $name
    $letsencrypt_name = $server_name

    $realm_host = regsubst($server_name, '\.', '-')
    $realm_name = "${realm_host}.${realm}"

    $listen_options = ''
    $ipv6_listen_options = ''
  }

  if $ssl {
    $certfile = "${::letsencrypt::cert_root}/${letsencrypt_name}/fullchain.pem"
    $keyfile = "${::letsencrypt::cert_root}/${letsencrypt_name}/privkey.pem"
    $ssl_headers = {
      'Strict-Transport-Security' => 'max-age=31536000; includeSubdomains',
      'X-Frame-Options'           => 'DENY',
      'X-Content-Type-Options'    => nosniff,
    }
  } else {
    $certfile = undef
    $keyfile = undef
    $ssl_headers = {}
  }

  # array of all provided hostnames
  $server_names = concat([], $server_name, $subdomains, $realm_name)

  # configure non-www compliancy
  # http://web.archive.org/web/20101230024259/http://no-www.org:80/faq.php
  # www point to the same content as non-www domains
  if $nowww_compliance == 'class_a' {
    $rewrite_www_to_non_www = false
    # add letsencrypt hostnames with www for every hostname
    $le_subdomains = unique(concat($subdomains, prefix(concat([], $letsencrypt_name, $subdomains), 'www.'), $realm_name))
    # listen to name, subdomains and all www. version of them
    $listen_domains = concat([], $server_name, $le_subdomains, $realm_name)
    $validate_domains = join($server_names, ' ')
    if $validate_domains !~ '^(?!.*www\.).*$' {
      fail("Class A no-www compliance specified, but www. domain specified in title or subdomains : ${validate_domains}.")
    }
  }
  # www domains redirect to non-www domains
  if $nowww_compliance == 'class_b' {
    $rewrite_www_to_non_www = true
    # add letsencrypt hostnames with www for every hostname
    $le_subdomains = unique(concat($subdomains, prefix(concat([], $letsencrypt_name, $subdomains), 'www.'), $realm_name))
    # www-redirect manages www names, only listen to name and subdomains
    $listen_domains = concat([], $server_name, $subdomains, $realm_name)
    $validate_domains = join($server_names, ' ')
    if $validate_domains !~ '^(?!.*www\.).*$' {
      fail("Class B no-www compliance specified, but www. domain specified in title or subdomains : ${validate_domains}.")
    }
  }
  # www domains do not exist
  if $nowww_compliance == 'class_c' {
    $rewrite_www_to_non_www = false
    $le_subdomains = unique(concat($subdomains, $realm_name))
    # only listen to name and subdomains
    $listen_domains = concat([], $server_name, $subdomains, $realm_name)
    $validate_domains = join($server_names, ' ')
    if $validate_domains !~ '^(?!.*www\.).*$' {
      fail("Class C no-www compliance specified, but a wwww. domain in subdomains: ${validate_domains}.")
    }
  }

  nginx::resource::server { $name:
    server_name                 => concat($listen_domains, prefix($listen_domains, 'www.')),
    listen_options              => $listen_options,
    ipv6_listen_options         => $ipv6_listen_options,
    ipv6_enable                 => true,
    ssl                         => $ssl,
    ssl_key                     => $keyfile,
    ssl_cert                    => $certfile,
    ssl_ciphers                 => $ssl_ciphers,
    ssl_dhparam                 => $ssl_dhparam,
    # return empty response on default location
    location_custom_cfg_prepend => {
      'return' => '444;',
    }
  }

  # configure letsencrypt
  if $ssl {
    letsencrypt::domain{ $letsencrypt_name:
      subdomains => $le_subdomains,
    }
    nginx::resource::location { "letsencrypt_${name}":
      location       => '^~ /.well-known/acme-challenge',
      server         => $name,
      location_alias => $::letsencrypt::www_root,
      priority       => 401,
      auth_basic     => off,
    }
    if $rewrite_www_to_non_www {
      nginx::resource::location { "letsencrypt_www-${name}":
        location       => '^~ /.well-known/acme-challenge',
        server         => "www-${name}",
        location_alias => $::letsencrypt::www_root,
        priority       => 401,
        auth_basic     => off,
      }
    }
  }
}
