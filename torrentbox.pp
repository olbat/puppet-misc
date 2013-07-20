# This receipe depends on the class "transmission_daemon" (http://github.com/olbat/puppet-transmission_daemon) and "lighttpd_secure_proxy" (http://github.com/olbat/puppet-lighttpd_secure_proxy).
# Append this at the bottom of /etc/puppet/manifests/site.pp

node 'tbox.lan' {
  ## Global config
  $bt_address = '127.0.0.1'
  $bt_port = 9091
  $bt_url = '/bt'
  $bt_blocklist = 'http://list.iblocklist.com/?list=bt_level1'
  $trusted_net = '192.168.0.0/24'
  $ssl_cert = 'lighttpd.pem' # This file have to be present in the modules/lighttpd_secure_proxy/files directory
  $htpasswd_file = 'bt.passwd' # This file have to be present in the modules/lighttpd_secure_proxy/files directory
  $nas_address = '//nas.lan'
  $nas_kind = 'cifs'
  $nas_mount_dir = '/media/nas'
  $nas_mount_options = '_netdev,...'

  ## NAS
  case $nas_kind {
    cifs: {
      package { 'cifs-utils':
        ensure => installed,
        before => Mount[$nas_mount_dir],
      }
    }
    nfs: {
      package { 'nfs-common':
        ensure => installed,
        before => Mount[$nas_mount_dir],
      }
      package { 'rpcbind':
        ensure => installed,
        before => Mount[$nas_mount_dir],
      }
      service { 'nfs-common':
        ensure => running,
        enable => true,
        hasstatus => true,
        require => Package['nfs-common'],
      }
      service { 'rpcbind':
        ensure => running,
        enable => true,
        hasstatus => false,
        require => Package['rpcbind'],
      }
    }
  }
  
  # Create NAS mount directory
  file { $nas_mount_dir:
    ensure => directory,
    recurse => true,
  }

  # Mount the NAS
  mount { $nas_mount_dir:
    device => $nas_address,
    atboot => true,
    ensure => mounted,
    fstype => $nas_kind,
    options => $nas_mount_options,
    require => File[$nas_mount_dir],
  }

  ## Transmission bittorrent rpc daemon
  class {'transmission_daemon':
    download_dir => "${nas_mount_dir}/bittorrent",
    incomplete_dir => "/var/lib/transmission-daemon/downloads",
    rpc_url => "${bt_url}",
    rpc_port => $bt_port,
    rpc_whitelist => [$bt_address],
    blocklist_url => $bt_blocklist,
  }

  ## Secure export on https
  lighttpd_secure_proxy::htpasswd_file{$htpasswd_file:
    srcfile => "puppet:///modules/lighttpd_secure_proxy/${htpasswd_file}",
    destfile => $htpasswd_file,
  }

  class {'lighttpd_secure_proxy':
    certificate => "puppet:///modules/lighttpd_secure_proxy/${ssl_cert}",
    exports => [
      {
        'path_regexp' => "^${bt_url}",
        'address' => $bt_address,
        'port' => $bt_port,
        'htpasswd_file' => $htpasswd_file,
        'trusted_net' => $trusted_net,
      },
    ]
  }
  Mount[$nas_mount_dir] -> Class['transmission_daemon']
  Class['transmission_daemon'] -> Class['lighttpd_secure_proxy']
}
