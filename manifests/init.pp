# Class: roundcube
#
# This module manages roundcube
#
# Parameters: none
#
# Actions:
#
# Requires: see Modulefile
#
# Sample Usage:
#
class roundcube ($db_password) {
  # main.inc options
  $default_host = 'localhost'
  $default_port = 143

  # yay, roundcube always needs password+tcp, because it effin cannot use the unix socket
  validate_re($db_password, '.')

  package { ["roundcube", "roundcube-pgsql", "roundcube-plugins", "roundcube-plugins-extra"]: ensure => installed; }

  postgresql::dbcreate { "roundcube":
    role     => 'www-data',
    encoding => 'UTF-8',
    locale   => 'en_US.UTF-8',
    template => 'template0';
  } ->
  postgresql::import { "roundcube-init":
    source_url      => 'file:////usr/share/dbconfig-common/data/roundcube/install/pgsql',
    user            => 'www-data',
    log             => "/var/lib/roundcube-dbimport/log",
    errorlog        => "/var/lib/roundcube-dbimport/errorlog",
    flagfile        => "/var/lib/roundcube-dbimport/flagfile",
    database        => 'roundcube',
    extract_command => false;
  }

  if ($db_password != '') {
    Postgresql::Dbcreate["roundcube"] {
      password => $db_password,
      address  => "::1/128",
    }
  } else {
    Postgresql::Dbcreate["roundcube"] {
      conntype    => 'local',
      address     => '',
      auth_method => 'peer',
    }
  }

  file {
    "/etc/dbconfig-common/roundcube.conf":
      content => template("roundcube/dbc.roundcube.conf.erb"),
      mode    => 0600,
      owner   => root,
      group   => root,
      require => [Package["roundcube"], Package["roundcube-pgsql"]],
      notify  => Exec["dpkg-reconfigure-roundcube"];

    "/etc/roundcube/debian-db.php":
      content => template("roundcube/debian-db.php.erb"),
      mode    => 0640,
      owner   => root,
      group   => www-data,
      require => [Package["roundcube"], Package["roundcube-pgsql"], Exec["dpkg-reconfigure-roundcube"]];

    "/etc/roundcube/main.inc.php":
      content => template("roundcube/main.inc.php.erb"),
      mode    => 0640,
      owner   => root,
      group   => www-data,
      require => [Package["roundcube"], Package["roundcube-pgsql"], Exec["dpkg-reconfigure-roundcube"]];

    "/var/lib/roundcube-dbimport":
      ensure => directory,
      mode   => 0700,
      owner  => www-data;
  }

  exec { "dpkg-reconfigure-roundcube":
    command     => '/usr/sbin/dpkg-reconfigure roundcube',
    refreshonly => true,
    logoutput   => on_failure;
  }
}
