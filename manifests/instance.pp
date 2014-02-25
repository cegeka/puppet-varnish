#
#
#== Definition: varnish::instance
#
#Creates a running varnishd instance and configures it's different startup
#parameters. Optionnally a VCL configuration file can be provided. Have a look
#at http://varnish.projects.linpro.no/wiki/Introduction for more details.
#
#
#Parameters:
#- *address*: array of ip + port which varnish's http service should bindto,
#  defaults to all interfaces on port 80.
#- *admin_address*: address of varnish's admin console, defaults to localhost.
#- *admin_port*: port of varnish's admin console, defaults to 6082.
#- *backend*: location of the backend, in the "address:port" format. This is
#  passed to "varnishd -b". Defaults to none.
#- *vcl_file*: location of the instance's VCL file, located on puppet's
#  fileserver (puppet://host/module/path.vcl). This is passed to "varnishd -f".
#  Defaults to none.
#- *vcl_content*: content of the instance's VCL file. Defaults to none.
#- *storage*: array of backend "type[,options]" strings to be passed to "varnishd -s"
#  since version 2.0 varnish support multiple storage files
#- *params*: array of "key=value" strings to be passed to "varnishd -p"
#  (run-time parameters). Defaults to none.
#- *nfiles*: max number of open files (ulimit -n) allocated to varnishd,
#  defaults to 131072.
#- *memlock*: max memory lock size (ulimit -l) allocated to varnishd, defaults
#  to 82000.
#- *corelimit*: size of coredumps (ulimit -c). Usually "unlimited" or 0,
#  defaults to 0.
#- *varnishlog*: whether a varnishlog instance must be run together with
#  varnishd. defaults to true.
#
#See varnishd(1) and /etc/{default,sysconfig}/varnish for more details.
#
#Notes:
#- varnish's configuration will be reloaded when it changes, using
#  /usr/local/sbin/vcl-reload.sh
#
#Requires:
#- Class['varnish']
#

define varnish::instance(
  $address=[':80'],
  $admin_address='localhost',
  $admin_port='6082',
  $backend=undef,
  $storage=[],
  $options=[],
  $nfiles='131072',
  $memlock='82000',
  $corelimit='0',
  $varnishlog=true,
  $cliparams=undef,
  $release='2',
  $environment='production'
) {

  # use a more comprehensive attribute name for ERB templates.
  $instance = $name

  # All the startup options are defined in /etc/{default,sysconfig}/varnish-${instance}
  $varnishsysconfig =  $::operatingsystem ? {
    /Debian|Ubuntu|kFreeBSD/        => "/etc/default/varnish-${instance}",
    /RedHat|Fedora|CentOS|Amazon/   => "/etc/sysconfig/varnish-${instance}",
  }

  file { "varnish-${instance} startup config":
    ensure  => present,
    content => template('varnish/sysconfig/varnish.erb'),
    name    => $varnishsysconfig,
  }

  file { "/etc/varnish/${instance}.vcl":
    ensure  => present,
    content => template('varnish/site.d/default.erb'),
    notify  => Service["varnish-${instance}"],
    require => Package['varnish'],
  }

  file { "/etc/varnish/${instance}/${environment}-${release}.vcl":
    ensure  => present,
    content => template("varnish/site.d/${environment}-${release}.erb"),
    notify  => Service["varnish-${instance}"],
    require => [Package['varnish'],File["/etc/varnish/${instance}"]],
  }

  file { "/etc/varnish/${instance}/error.vcl":
    ensure  => present,
    content => template('varnish/site.d/error.erb'),
    notify  => Service["varnish-${instance}"],
    require => [Package['varnish'],File["/etc/varnish/${instance}"]],
  }

  file { "/etc/varnish/${instance}/error-404.vcl":
    ensure  => present,
    content => template('varnish/site.d/error-404.erb'),
    notify  => Service["varnish-${instance}"],
    require => [Package['varnish'],File["/etc/varnish/${instance}"]],
  }

  file { "/etc/varnish/${instance}/acl.vcl":
    ensure  => present,
    source  => 'puppet:///modules/varnish/site.d/acl.vcl',
    notify  => Service["varnish-${instance}"],
    require => [Package['varnish'],File["/etc/varnish/${instance}"]],
  }

  file { "/var/lib/varnish/${instance}":
    ensure  => directory,
    owner   => 'root',
    require => Package['varnish'],
  }
  file { "/etc/varnish/${instance}":
    ensure  => directory,
    owner   => 'root',
    require => Package['varnish'],
  }

  $varnishinitd = $::operatingsystem ? {
    /Debian|Ubuntu|kFreeBSD/        => template('varnish/varnish.debian.erb'),
    /RedHat|Fedora|CentOS|Amazon/   => template('varnish/varnish.redhat.erb'),
  }

  file { "/etc/init.d/varnish-${instance}":
    ensure  => present,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => $varnishinitd,
  }

  $real_varnishlog = $::operatingsystem ? {
    /Debian|Ubuntu|kFreeBSD/        => template('varnish/varnishlog.debian.erb'),
    /RedHat|Fedora|CentOS|Amazon/   => template('varnish/varnishlog.redhat.erb'),
  }

  file { "/etc/init.d/varnishlog-${instance}":
    ensure  => present,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => $real_varnishlog,
  }

  file { '/usr/local/sbin/vcl-reload-${instance}.sh':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => template("${module_name}/usr/local/sbin/vcl-reload.sh.erb"),
  }

  service { "varnish-${instance}":
    ensure  => running,
    enable  => true,
    pattern => "/var/run/varnish-${instance}.pid",
    # reload VCL file when changed, without restarting the varnish service.
    restart => "/usr/local/sbin/vcl-reload-${instance}.sh /etc/varnish/${instance}.vcl",
    require => [
      File["/etc/init.d/varnish-${instance}"],
      File['/usr/local/sbin/vcl-reload-${instance}.sh'],
      File["varnish-${instance} startup config"],
      File["/var/lib/varnish/${instance}"],
      Service['varnish'],
      Service['varnishlog']
    ],
  }

  if ($varnishlog == true ) {

    service { "varnishlog-${instance}":
      ensure    => running,
      enable    => true,
      pattern   => "/var/run/varnishlog-${instance}.pid",
      hasstatus => false,
      require   => [
        File["/etc/init.d/varnishlog-${instance}"],
        Service["varnish-${instance}"],
      ],
    }

  } else {

    service { "varnishlog-${instance}":
      ensure    => stopped,
      enable    => false,
      pattern   => "/var/run/varnishlog-${instance}.pid",
      hasstatus => false,
      require   => File["/etc/init.d/varnishlog-${instance}"],
    }
  }
}
