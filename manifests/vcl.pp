define varnish::vcl (
  $type     = undef,
  $prio     = 20,
  $rules    = undef,
  $instance = undef,
) {

  #concat { "/etc/varnish/${instance}/${type}.vcl": }
  concat::fragment { "${varnish::vcl::title}-${varnish::vcl::rule}-vcl":
    target  => "/etc/varnish/${varnish::vcl::instance}/${varnish::vcl::type}.vcl",
    content => template('varnish/site.d/custom-vcl.erb'),
    order   => $prio,
  }

}
