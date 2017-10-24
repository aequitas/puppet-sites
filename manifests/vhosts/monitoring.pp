# declare monitoring plugins to be realised at a later point
define sites::vhosts::monitoring (
  $server_name=undef,
){
  # monitor cache performance
  @collectd::plugin::tail::file { "nginx-cache-${name}":
    filename => "/var/log/nginx/${server_name}.cache.log",
    instance => "nginx-cache-${name}",
    matches  => [
      {
        regex    => '^[a-f0-9\.:]+ - HIT',
        dstype   => 'CounterInc',
        type     => 'counter',
        instance => 'hit',
      },
      {
        regex    => '^[a-f0-9\.:]+ - MISS',
        dstype   => 'CounterInc',
        type     => 'counter',
        instance => 'miss',
      },
      {
        regex    => '^[a-f0-9\.:]+ - EXPIRED',
        dstype   => 'CounterInc',
        type     => 'counter',
        instance => 'expired',
      },
      {
        regex    => '^[a-f0-9\.:]+ - STALE',
        dstype   => 'CounterInc',
        type     => 'counter',
        instance => 'stale',
      },
      {
        regex    => '^[a-f0-9\.:]+ - -',
        dstype   => 'CounterInc',
        type     => 'counter',
        instance => 'no_cache',
      },
    ]
  }

  # monitor protocol types
  @collectd::plugin::tail::file { "nginx-protocol-${name}":
    filename => "/var/log/nginx/ssl-${server_name}.access.log",
    instance => "nginx-protocol-${name}",
    matches  => [
      {
        regex    => '[0-9\.]+ -',
        dstype   => 'CounterInc',
        type     => 'counter',
        instance => 'v4',
      },
      {
        regex    => '^[a-f0-9:]+ -',
        dstype   => 'CounterInc',
        type     => 'counter',
        instance => 'v6',
      },
      {
        regex    => ' HTTP/1.1',
        dstype   => 'CounterInc',
        type     => 'counter',
        instance => 'http11',
      },
      {
        regex    => ' HTTP/2',
        dstype   => 'CounterInc',
        type     => 'counter',
        instance => 'http2',
      },
    ]
  }

  # monitor responses
  @collectd::plugin::tail::file { "nginx-responses-${name}":
    filename => "/var/log/nginx/ssl-${server_name}.access.log",
    instance => "nginx-responses-${name}",
    matches  => [
      {
        regex    => 'HTTP/[^ ]+ 200 ',
        dstype   => 'CounterInc',
        type     => 'counter',
        instance => 'ok',
      },
      {
        regex    => 'HTTP/[^ ]+ 404 ',
        dstype   => 'CounterInc',
        type     => 'counter',
        instance => 'not_found',
      },
      {
        regex    => 'HTTP/[^ ]+ 5[0-9][0-9] ',
        dstype   => 'CounterInc',
        type     => 'counter',
        instance => '5xx',
      },
      {
        regex    => 'HTTP/[^ ]+ 4[0-9][0-9] ',
        dstype   => 'CounterInc',
        type     => 'counter',
        instance => '4xx',
      },
      {
        regex    => 'HTTP/[^ ]+ 3[0-9][0-9] ',
        dstype   => 'CounterInc',
        type     => 'counter',
        instance => '3xx',
      },
      {
        regex    => 'HTTP/[^ ]+ 2[0-9][0-9] ',
        dstype   => 'CounterInc',
        type     => 'counter',
        instance => '2xx',
      },
    ]
  }
}
