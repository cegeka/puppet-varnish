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

  package { ['varnish','jemalloc']:
    ensure => $real_release,
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
      # By default RPM package fail to send HUP to varnishlog process, and don't
      # bother compressing rotated files. This fixes these issues, waiting for
      # this bug to get corrected upstream:
      # https://bugzilla.redhat.com/show_bug.cgi?id=554745
      augeas { 'logrotate config for varnishlog and varnishncsa':
        incl    => '/etc/logrotate.d/varnish',
        lens    => 'Logrotate.lns',
        changes => [
          'set rule/schedule daily',
          'set rule/rotate 7',
          'set rule/compress compress',
          'set rule/size 40M',
          'set rule/delaycompress delaycompress',
          'set rule/postrotate "for service in varnishlog varnishncsa varnishd; do if /usr/bin/pgrep -P 1 $service >/dev/null; then /usr/bin/pkill -HUP $service 2>/dev/null; fi; done"',
        ],
        require => Package['varnish'],
      }
    }
    default: {}
  }
}
