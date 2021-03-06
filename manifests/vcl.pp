define varnish::vcl (
  $type     = undef,
  $prio     = 20,
  $rules    = undef,
  $instance = undef,
) {

  concat::fragment { "${instance}-${title}-${type}-vcl":
    target  => "/etc/varnish/${instance}/${type}.vcl",
    content => template('varnish/site.d/custom-vcl.erb'),
    order   => $prio,
    notify  => Service["varnish-${instance}"],
  }

}
