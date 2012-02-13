%define _unpackaged_files_terminate_build      0
%define install_base /opt/perfsonar_ps/toolkit

%define apacheconf    apache-toolkit_web_gui.conf

%define init_script_1 services_init_script
%define init_script_2 config_daemon
%define init_script_3 discover_external_address
%define init_script_4 generate_motd

# The following init scripts are only enabled when the LiveCD is being used
%define init_script_5 toolkit_config
%define init_script_6 mount_scratch_overlay
%define init_script_7 generate_cert_init_script

%define crontab_1     cron-service_watcher
%define crontab_2     cron-cacti_local
%define crontab_3     cron-owamp_cleaner
%define crontab_4     cron-save_config

%define relnum 2
%define disttag pSPS

Name:           perl-perfSONAR_PS-Toolkit
Version:        3.2
Release:        %{relnum}.%{disttag}
Summary:        perfSONAR_PS Toolkit
License:        distributable, see LICENSE
Group:          Development/Libraries
URL:            http://search.cpan.org/dist/perfSONAR_PS-Toolkit
Source0:        perfSONAR_PS-Toolkit-%{version}.%{relnum}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch
Requires:		perl(AnyEvent) >= 4.81
Requires:              perl(AnyEvent::HTTP)
Requires:              perl(CGI)
Requires:              perl(CGI::Ajax)
Requires:              perl(CGI::Carp)
Requires:              perl(CGI::Session)
Requires:              perl(Class::Accessor)
Requires:              perl(Class::Fields)
Requires:              perl(Config::General)
Requires:              perl(Cwd)
Requires:              perl(Data::Dumper)
Requires:              perl(Data::UUID)
Requires:              perl(Data::Validate::Domain)
Requires:              perl(Data::Validate::IP)
Requires:              perl(Date::Manip)
Requires:              perl(Digest::MD5)
Requires:              perl(English)
Requires:              perl(Exporter)
Requires:              perl(Fcntl)
Requires:              perl(File::Basename)
Requires:              perl(FindBin)
Requires:              perl(Getopt::Long)
Requires:              perl(IO::File)
Requires:              perl(IO::Interface)
Requires:              perl(IO::Socket)
Requires:              perl(JSON::XS)
Requires:              perl(LWP::Simple)
Requires:              perl(LWP::UserAgent)
Requires:              perl(Log::Log4perl)
Requires:              perl(Net::DNS)
Requires:              perl(Net::IP)
Requires:              perl(Net::IPv6Addr)
Requires:              perl(Net::Ping)
Requires:              perl(Net::Server)
Requires:              perl(NetAddr::IP)
Requires:              perl(POSIX)
Requires:              perl(Params::Validate)
Requires:              perl(RPC::XML::Client)
Requires:              perl(RPC::XML::Server)
Requires:              perl(Readonly)
Requires:              perl(Regexp::Common)
Requires:              perl(Scalar::Util)
Requires:              perl(Socket)
Requires:              perl(Storable)
Requires:              perl(Sys::Hostname)
Requires:              perl(Template)
Requires:              perl(Term::ReadLine)
Requires:              perl(Time::HiRes)
Requires:              perl(Time::Local)
Requires:		perl(XML::LibXML) >= 1.60
Requires:              perl(aliased)
Requires:              perl(base)
Requires:              perl(lib)
Requires:              perl(utf8)
Requires:              perl(vars)
Requires:              perl(version)
Requires:              perl(warnings)
Requires:       perl
Requires:       httpd
Requires:       mod_ssl
Requires:       mod_auth_shadow
Requires:       ntp
Requires:       iperf
Requires:       bwctl-server
Requires:       owamp-server
Requires:       bwctl-client
Requires:       owamp-client
Requires:       perl-perfSONAR_PS-LSCacheDaemon
Requires:       perl-perfSONAR_PS-LSRegistrationDaemon
Requires:       perl-perfSONAR_PS-PingER-server
Requires:       perl-perfSONAR_PS-LookupService
Requires:       perl-perfSONAR_PS-perfSONARBUOY-server
Requires:       perl-perfSONAR_PS-perfSONARBUOY-client
Requires:       perl-perfSONAR_PS-SNMPMA
Requires:       ndt
Requires:       npad
# the following RPMs are needed by cacti
Requires:       net-snmp-utils
Requires:       mod_php
Requires:       php-adodb
Requires:       php-mysql
Requires:       php-pdo
Requires:       php-snmp


%description
XXX: add something

%package LiveCD
Summary:        pS-Performance Toolkit Live CD utilities
Group:          Applications/Network
Requires:       perl-perfSONAR_PS-Toolkit
Requires:       aufs

%description LiveCD
XXX: add something

%pre
/usr/sbin/groupadd perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%prep
%setup -q -n perfSONAR_PS-Toolkit-%{version}.%{relnum}

%build

%install
rm -rf $RPM_BUILD_ROOT

make ROOTPATH=$RPM_BUILD_ROOT/%{install_base} rpminstall

install -D -m 600 scripts/%{crontab_1} $RPM_BUILD_ROOT/etc/cron.d/%{crontab_1}
install -D -m 600 scripts/%{crontab_2} $RPM_BUILD_ROOT/etc/cron.d/%{crontab_2}
install -D -m 600 scripts/%{crontab_3} $RPM_BUILD_ROOT/etc/cron.d/%{crontab_3}
install -D -m 600 scripts/%{crontab_4} $RPM_BUILD_ROOT/etc/cron.d/%{crontab_4}

install -D -m 644 scripts/%{apacheconf} $RPM_BUILD_ROOT/etc/httpd/conf.d/%{apacheconf}

install -D -m 755 init_scripts/%{init_script_1} $RPM_BUILD_ROOT/etc/init.d/%{init_script_1}
install -D -m 755 init_scripts/%{init_script_2} $RPM_BUILD_ROOT/etc/init.d/%{init_script_2}
install -D -m 755 init_scripts/%{init_script_3} $RPM_BUILD_ROOT/etc/init.d/%{init_script_3}
install -D -m 755 init_scripts/%{init_script_4} $RPM_BUILD_ROOT/etc/init.d/%{init_script_4}
install -D -m 755 init_scripts/%{init_script_5} $RPM_BUILD_ROOT/etc/init.d/%{init_script_5}
install -D -m 755 init_scripts/%{init_script_6} $RPM_BUILD_ROOT/etc/init.d/%{init_script_6}
install -D -m 755 init_scripts/%{init_script_7} $RPM_BUILD_ROOT/etc/init.d/%{init_script_7}

%post
mkdir -p /var/log/perfsonar
chown perfsonar:perfsonar /var/log/perfsonar
mkdir -p /var/log/perfsonar/web_admin
chown apache:perfsonar /var/log/perfsonar/web_admin
mkdir -p /var/log/cacti
chown apache /var/log/cacti

mkdir -p /var/run/web_admin_sessions
chown apache /var/run/web_admin_sessions

mkdir -p /var/run/toolkit/

# Create the cacti RRD location
mkdir -p /var/lib/cacti/rra
chown apache /var/lib/cacti/rra
ln -s /var/lib/cacti/rra /opt/perfsonar_ps/toolkit/web/root/admin/cacti

# Overwrite the existing configuration files for the services with new
# configuration files containing the default settings.
cp -f /opt/perfsonar_ps/toolkit/etc/default_service_configs/hLS.conf /opt/perfsonar_ps/lookup_service/etc/daemon.conf
cp -f /opt/perfsonar_ps/toolkit/etc/default_service_configs/ls_registration_daemon.conf /opt/perfsonar_ps/ls_registration_daemon/etc/ls_registration_daemon.conf
cp -f /opt/perfsonar_ps/toolkit/etc/default_service_configs/pinger.conf /opt/perfsonar_ps/PingER/etc/daemon.conf
cp -f /opt/perfsonar_ps/toolkit/etc/default_service_configs/psb_ma.conf /opt/perfsonar_ps/perfsonarbuoy_ma/etc/daemon.conf
cp -f /opt/perfsonar_ps/toolkit/etc/default_service_configs/hLS.conf /opt/perfsonar_ps/lookup_service/etc/daemon.conf
cp -f /opt/perfsonar_ps/toolkit/etc/default_service_configs/snmp_ma.conf /opt/perfsonar_ps/snmp_ma/etc/daemon.conf

# we need all these things readable the CGIs (XXX: the configuration daemon
# should be how they read these, but that'd require a fair number of changes,
# so we'll put that in the "maybe" category.
chmod o+r /opt/perfsonar_ps/lookup_service/etc/daemon.conf
chmod o+r /opt/perfsonar_ps/ls_registration_daemon/etc/ls_registration_daemon.conf
chmod o+r /opt/perfsonar_ps/perfsonarbuoy_ma/etc/daemon.conf
chmod o+r /opt/perfsonar_ps/PingER/etc/daemon.conf
chmod o+r /opt/perfsonar_ps/perfsonarbuoy_ma/etc/owmesh.conf
chmod o+r /opt/perfsonar_ps/PingER/etc/pinger-landmarks.xml
chmod o+r /opt/perfsonar_ps/snmp_ma/etc/daemon.conf
chmod o+r /opt/perfsonar_ps/toolkit/etc/administrative_info
chmod o+r /opt/perfsonar_ps/toolkit/etc/enabled_services
chmod o+r /opt/perfsonar_ps/toolkit/etc/external_addresses
chmod o+r /opt/perfsonar_ps/toolkit/etc/ntp_known_servers
chmod o+r /etc/bwctld/bwctld.limits
chmod o+r /etc/bwctld/bwctld.keys
chmod o+r /etc/owampd/owampd.limits
chmod o+r /etc/owampd/owampd.pfs

chkconfig %{init_script_1} on
chkconfig %{init_script_2} on
chkconfig %{init_script_3} on
chkconfig %{init_script_4} on

# apache needs to be on for the toolkit to work
chkconfig --level 2345 httpd on

echo "-------------------------------------------------------"
echo "                    IMPORTANT NOTE                     "
echo "-------------------------------------------------------"
echo "In order to finish the Toolkit installation run:       "
echo "/opt/perfsonar_ps/toolkit/scripts/initialize_databases "
echo "This will initialize the databases so that the         "
echo "toolkit will function properly                         "
echo "-------------------------------------------------------"

%post LiveCD
# The toolkit_config init script is only enabled when the LiveCD is being used
# so it gets enabled as part of the kickstart.
chkconfig %{init_script_5} on
chkconfig %{init_script_6} on
chkconfig %{init_script_7} on

mkdir -p /mnt/store
mkdir -p /mnt/temp_root

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(0644,perfsonar,perfsonar,0755)
#%doc %{install_base}/doc/*
%config %{install_base}/etc/*
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/*
%{install_base}/lib/*
%{install_base}/python_lib/*
%{install_base}/web/*
%{install_base}/templates/*
%{install_base}/dependencies
/etc/httpd/conf.d/*
%attr(0644,root,root) /etc/cron.d/%{crontab_1}
%attr(0644,root,root) /etc/cron.d/%{crontab_2}
%attr(0644,root,root) /etc/cron.d/%{crontab_3}
# Make sure the cgi scripts are all executable
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/gui/jowping/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/gui/services/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/gui/reverse_traceroute.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/gui/perfAdmin/serviceTest.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/gui/perfAdmin/directory.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/gui/perfAdmin/bandwidthGraphScatter.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/gui/perfAdmin/utilizationGraphFlash.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/gui/perfAdmin/bandwidthGraphFlash.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/gui/perfAdmin/PingERGraph.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/gui/perfAdmin/delayGraph.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/gui/perfAdmin/utilizationGraph.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/gui/perfAdmin/bandwidthGraph.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/admin/bwctl/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/admin/regular_testing/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/admin/owamp/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/admin/ntp/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/admin/administrative_info/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/admin/enabled_services/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/init_scripts/%{init_script_1}
%attr(0755,perfsonar,perfsonar) %{install_base}/init_scripts/%{init_script_2}
%attr(0755,perfsonar,perfsonar) %{install_base}/init_scripts/%{init_script_3}
%attr(0755,perfsonar,perfsonar) %{install_base}/init_scripts/%{init_script_4}
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{init_script_1}
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{init_script_2}
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{init_script_3}
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{init_script_4}
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/cacti_toolkit_init.sql
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/clean_owampd
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/discover_external_address
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/initialize_cacti_database
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/initialize_databases
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/initialize_perfsonarbuoy_bwctl_database
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/initialize_perfsonarbuoy_owamp_database
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/initialize_pinger_database
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/manage_users
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/nptoolkit-configure.py
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/NPToolkit.version
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/pinger_toolkit_init.sql
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/reset_pinger.sh
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/reset_psb_bwctl.sh
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/reset_psb_owamp.sh
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/service_watcher
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/set_default_passwords
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/watcher_log_archive
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/watcher_log_archive_cleanup

%files LiveCD
%attr(0644,root,root) /etc/cron.d/%{crontab_4}
%attr(0755,perfsonar,perfsonar) %{install_base}/init_scripts/%{init_script_5}
%attr(0755,perfsonar,perfsonar) %{install_base}/init_scripts/%{init_script_6}
%attr(0755,perfsonar,perfsonar) %{install_base}/init_scripts/%{init_script_7}
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{init_script_5}
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{init_script_6}
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{init_script_7}
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/create_backing_store
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/restore_config
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/save_config
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/temp_root.img
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/upgrade_3.1.x.sh

%changelog
* Wed Jun 18 2010 aaron@internet2.edu 3.2-1
- Initial RPM release
