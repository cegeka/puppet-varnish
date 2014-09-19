include varnish

varnish::instance { 'site.example.com':
  address     => ['0.0.0.0:80'],
  admin_port  => '6083',
  options     => [
    'host = "127.0.0.1"',
    'port = "8080"',
    'connect_timeout = 600s',
    'first_byte_timeout = 600s',
    'between_bytes_timeout = 600s'
  ],
  storage     => ['file,/var/lib/varnish/varnish_storage.bin,1G'],
  release     => '3',
}

varnish::vcl { 'allow-backend':
  type     => 'recv',
  rules    => [
    'if (req.url ~ "^/api/") {
      return (pass);
    }'
  ],
  instance => 'site.example.com',
}
