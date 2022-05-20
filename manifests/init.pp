#
#
#== Class: varnish
#
#Installs the varnish http accelerator and stops the varnishd and varnishlog
#services, because they are handled separately by varnish::instance.
#
#
class varnish($release=undef) {

  if $release {
    $real_release = $release
  } else {
    $real_release = $epel_release
  }

  package { 'varnish':
    ensure => $real_release,
  }

  package { 'jemalloc':
    ensure => present
  }

  service { 'varnish':
    ensure    => 'stopped',
    enable    => false,
    pattern   => '/var/run/varnishd.pid',
    hasstatus => false,
    require   => Package['varnish'],
  }

  service { 'varnishlog':
    ensure    => 'stopped',
    enable    => false,
    pattern   => '/var/run/varnishlog.pid',
    hasstatus => false,
    require   => Package['varnish'],
  }

  case $::operatingsystem {
    'RedHat','CentOS','Amazon': {
      case $::operatingsystemrelease {
        /^5./: {
          $epel_release = '2.0.6-2.el5'
        }
        /^6./: {
          $epel_release = '2.1.5-1.el6'
        }
        default: {
          $epel_release = ''
        }
      }
    }
    default: {}
  }
}
