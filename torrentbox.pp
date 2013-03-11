# This receipe depends on the class "transmission_daemon" (http://github.com/olbat/puppet-transmission_daemon) and "lighttpd_secure_proxy" (http://github.com/olbat/puppet-lighttpd_secure_proxy).
# Append this at the bottom of /etc/puppet/manifests/site.pp

node 'tbox.lan' {
  ## Global config
  $bt_address = '127.0.0.1'
  $bt_port = 9091
  $bt_url = '/bt'
  $nas_mount_dir = "/media/nas"

  ## NAS
  # Microsoft NAS export only
  package { 'cifs-utils':
    ensure => installed,
  }
  
  # Create NAS mount directory
  file { $nas_mount_dir:
    ensure => directory,
    recurse => true,
  }

  # Mount the NAS
  mount { $nas_mount_dir:
    device => '//nas.lan',
    atboot => true,
    ensure => mounted,
    fstype => 'cifs', # change it depending on the NAS export kind
    options => '_netdev', # append the mount options
    require => File[$nas_mount_dir],
  }

  ## Transmission bittorrent rpc daemon
  class {'transmission_daemon':
    download_dir => "${nas_mount_dir}/Bittorrent",
    incomplete_dir => "/var/lib/transmission-daemon/downloads",
    rpc_url => "${bt_url}/",
    rpc_port => $bt_port,
    rpc_whitelist => [$bt_address],
    blocklist_url => "http://list.iblocklist.com/?list=bt_level1"
  }

  ## Secure export on https
  lighttpd_secure_proxy::htpasswd_file{'bt.passwd':
    srcfile => 'puppet:///modules/lighttpd_secure_proxy/bt.passwd',
    destfile => 'bt.passwd', # This file have to be present in the modules/lighttpd_secure_proxy/files directory
  }

  class {'lighttpd_secure_proxy':
    certificate => 'puppet:///modules/lighttpd_secure_proxy/lighttpd.pem', # This file have to be present in the modules/lighttpd_secure_proxy/files directory
    exports => [
      {
        'path_regexp' => "^${bt_url}",
        'address' => $bt_address,
        'port' => $bt_port,
        'htpasswd_file' => 'bt.passwd',
      },
    ]
  }
  Mount[$nas_mount_dir] -> Class['transmission_daemon']
  Class['transmission_daemon'] -> Class['lighttpd_secure_proxy']
}
