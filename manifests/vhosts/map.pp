# map variables
class sites::vhosts::map {
  nginx::resource::map { 'cache_bypass_cookie':
    default  => "''",
    string   => '$http_cookie',
    mappings => {
      '~wordpress_logged_in_' => 1,
    }
  }
}
