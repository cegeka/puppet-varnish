include varnish

varnish::instance { 'site.example.com':
  address    => ['0.0.0.0:80'],
  admin_port => '6083',
  options    => [
    'host = "127.0.0.1"',
    'port = "8080"',
    'connect_timeout = 600s',
    'first_byte_timeout = 600s',
    'between_bytes_timeout = 600s'
  ],
  storage    => ['file,/var/lib/varnish/varnish_storage.bin,1G'],
}
