#
# Configure the Nuage plugin for neutron.
#
# === Parameters
#
# [*nuage_net_partition_name*]
#   (required) The net partition under which the VMs will be 
#   seen in the VSD 
#
# [*nuage_vsd_ip*]
#   (required) IP address of the Virtual Services Directory
#
# [*nuage_vsd_username*]
#   (required) Username to be used to log into VSD
#
# [*nuage_vsd_password*]
#   (required) Password to be used to log into VSD
#
# [*nuage_vsd_organization*]
#   (required) Parameter required to log into VSD
#
# [*nuage_base_uri_version*]
#   (required) URI version to be used based on the VSD release 
#   For example v3_0
#
# [*nuage_cms_id*]
#   (required) CMS ID generated by the VSD 
#
# [*nuage_auth_resource*]
#   (optional) The auth resource value to be use to connect 
#   to VSD. The default is /me
#
# [*nuage_server_ssl*]
#   (optional) Flag to determine whether to use ssl connection
#   to connect to VSD. The default is True 
#
# [*purge_config*]
#   (optional) Whether to set only the specified config options 
#   in the nuage config. 
#   Defaults to false.
#
class neutron::plugins::nuage (
  $nuage_net_partition_name,
  $nuage_vsd_ip,
  $nuage_vsd_username,
  $nuage_vsd_password,
  $nuage_vsd_organization,
  $nuage_base_uri_version,
  $nuage_cms_id,
  $nuage_auth_resource    = '/me',
  $nuage_server_ssl       = true,
  $purge_config           = false,
) {

  include ::neutron::params

  File['/etc/neutron/plugins/nuage/plugin.ini'] -> Neutron_plugin_nuage<||>
  Neutron_plugin_nuage<||> ~> Service['neutron-server']
  Neutron_plugin_nuage<||> ~> Exec<| title == 'neutron-db-sync' |>

  file { '/etc/neutron/plugins/nuage':
    ensure => directory,
  }

  if $::osfamily == 'Debian' {
    file_line { '/etc/default/neutron-server:NEUTRON_PLUGIN_CONFIG':
      path   => '/etc/default/neutron-server',
      match  => '^NEUTRON_PLUGIN_CONFIG=(.*)$',
      line   => "NEUTRON_PLUGIN_CONFIG=${::neutron::params::nuage_config_file}",
      notify => Service['neutron-server'],
    }
  }

  if $::osfamily == 'Redhat' {
    File['/etc/neutron/plugin.ini'] ~> Exec<| title == 'neutron-db-sync' |>
    file { '/etc/neutron/plugin.ini':
      ensure  => link,
      require => File['/etc/neutron/plugins/nuage/plugin.ini'],
      target  => $::neutron::params::nuage_config_file,
    }
  }

  file { '/etc/neutron/plugins/nuage/plugin.ini':
    ensure  => file,
    owner   => 'root',
    group   => 'neutron',
    require => File['/etc/neutron/plugins/nuage'],
    mode    => '0640'
  }

  resources { 'neutron_plugin_nuage':
    purge => $purge_config,
  }

  $nuage_base_uri_base = '/nuage/api'
  neutron_plugin_nuage {
    'RESTPROXY/default_net_partition_name': value => $nuage_net_partition_name;
    'RESTPROXY/server':                     value => $nuage_vsd_ip;
    'RESTPROXY/serverauth':                 value => "${nuage_vsd_username}:${nuage_vsd_password}";
    'RESTPROXY/organization':               value => $nuage_vsd_organization;
    'RESTPROXY/auth_resource':              value => $nuage_auth_resource;
    'RESTPROXY/serverssl':                  value => $nuage_server_ssl;
    'RESTPROXY/base_uri':                   value => "${nuage_base_uri_base}/${nuage_base_uri_version}";
    'RESTPROXY/cms_id':                     value => $nuage_cms_id;
  }

  if $::neutron::core_plugin != 'nuage_neutron.plugins.nuage.plugin.NuagePlugin' and
    $::neutron::core_plugin != 'nuage' and ($::neutron::core_plugin == 'neutron.plugins.ml2.plugin.Ml2Plugin' and
    !('nuage' in $::neutron::plugins::ml2::mechanism_drivers)) {
    fail('Nuage plugin should be the core_plugin or mechanism driver in neutron.conf')
  }
}
