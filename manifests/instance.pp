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
  $environment='production',
  $http_authorization_cache_disabled=true,
  $google_analytics_removal_enabled=true
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
  
 if  ( $::operatingsystem =~ /RedHat|CentOS/ ) and ($::operatingsystemmajrelease =~ /7/ ) {
   notice('YES')
   $service_script = "/usr/lib/systemd/system/varnish-${instance}.service"
   file { $service_script:
     ensure => present,
     mode   => '0755',
     owner  => 'root',
     group  => 'root',
     source => 'puppet:///modules/varnish/etc/init.d/varnish-instance.service',
     notify => Exec["daemon-reload"]
   }
 } else {
   notice('NO')
   $service_script = "/etc/init.d/varnish-${instance}"
   file { $service_script:
     ensure  => present,
     mode    => '0755',
     owner   => 'root',
     group   => 'root',
     content => $varnishinitd,
   }
 }

  if $release != 4 {
    $instance_template = 'varnish/site.d/default.erb'
  } else {
    $instance_template = 'varnish/site.d/default-4.erb'
  }
  file { "/etc/varnish/${instance}.vcl":
    ensure  => present,
    content => template($instance_template),
    notify  => Service["varnish-${instance}"],
    require => [Package['varnish'],File[$service_script]]
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
  if $release != 4 {
    file { "/etc/varnish/${instance}/acl.vcl":
      ensure  => present,
      source  => 'puppet:///modules/varnish/site.d/acl.vcl',
      notify  => Service["varnish-${instance}"],
      require => [Package['varnish'],File["/etc/varnish/${instance}"]],
    }
  } else {
    file { "/etc/varnish/${instance}/acl4.vcl":
      ensure  => present,
      source  => 'puppet:///modules/varnish/site.d/acl.vcl',
      notify  => Service["varnish-${instance}"],
      require => [Package['varnish'],File["/etc/varnish/${instance}"]],
    }
  }

  concat { "/etc/varnish/${instance}/recv.vcl": }
  concat { "/etc/varnish/${instance}/pass.vcl": }
  concat { "/etc/varnish/${instance}/fetch.vcl": }

  varnish::vcl { 'initial-recv-vcl':
    type     => 'recv',
    prio     => 10,
    rules    => ['# File managed by puppet'],
    instance => $instance
  }
  varnish::vcl { 'initial-pass-vcl':
    type     => 'pass',
    prio     => 10,
    rules    => ['# File managed by puppet'],
    instance => $instance
  }
  varnish::vcl { 'initial-fetch-vcl':
    type     => 'fetch',
    prio     => 10,
    rules    => ['# File managed by puppet'],
    instance => $instance
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

  file { "/usr/local/sbin/vcl-reload-${instance}.sh":
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
      File[$service_script],
      File["/usr/local/sbin/vcl-reload-${instance}.sh"],
      File["varnish-${instance} startup config"],
      File["/var/lib/varnish/${instance}"],
      Varnish::Vcl['initial-recv-vcl'],
      Varnish::Vcl['initial-pass-vcl'],
      Varnish::Vcl['initial-fetch-vcl'],
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
  exec { "daemon-reload":
    command     => '/usr/bin/systemctl daemon-reload',
    user        => 'root',
    refreshonly => true,
  }
}
