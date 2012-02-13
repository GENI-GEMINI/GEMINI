%define _unpackaged_files_terminate_build      0
%define install_base /opt/perfsonar_ps/perfsonarbuoy_ma

# init scripts must be located in the 'scripts' directory
%define init_script_ma perfsonarbuoy_ma
%define init_script_bw_collector perfsonarbuoy_bw_collector
%define init_script_bw_master perfsonarbuoy_bw_master
%define init_script_owp_collector perfsonarbuoy_owp_collector
%define init_script_owp_master perfsonarbuoy_owp_master

%define relnum 7
%define disttag pSPS

Name:           perl-perfSONAR_PS-perfSONARBUOY
Version:        3.1
Release:        %{relnum}.%{disttag}
Summary:        perfSONAR_PS perfSONAR-BUOY Measurement Archive and Collection System
License:        distributable, see LICENSE
Group:          Development/Libraries
URL:            http://search.cpan.org/dist/perfSONAR_PS-perfSONAR-BUOY/
Source0:        perfSONAR_PS-perfSONARBUOY-%{version}.%{relnum}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch
Requires:       perl
#Requires:       perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))

%description
perfSONARBUOY is a scheduled bandwidth and latency testing framework, storage system, and querable web service.

%package server
Summary:        perfSONAR_PS perfSONARBUOY Measurement Archive and Collection System
Group:          Applications/Network
Requires:		perl(Config::General)
Requires:		perl(Cwd)
Requires:		perl(DB_File)
Requires:		perl(DBI)
Requires:		perl(Data::UUID)
Requires:		perl(Date::Manip)
Requires:       perl(Data::Validate::IP)
Requires:		perl(Digest::MD5)
Requires:		perl(Error)
Requires:		perl(Exporter)
Requires:		perl(File::Path)
Requires:		perl(File::Temp)
Requires:		perl(FileHandle)
Requires:		perl(Getopt::Long)
Requires:		perl(Getopt::Std)
Requires:		perl(HTTP::Daemon)
Requires:		perl(IO::File)
Requires:		perl(IO::Socket)
Requires:		perl(LWP::Simple)
Requires:		perl(LWP::UserAgent)
Requires:		perl(Log::Log4perl)
Requires:		perl(Log::Dispatch)
Requires:		perl(Log::Dispatch::FileRotate)
Requires:		perl(Log::Dispatch::File)
Requires:		perl(Log::Dispatch::Syslog)
Requires:		perl(Log::Dispatch::Screen)
Requires:		perl(Math::BigFloat)
Requires:       perl(Math::Int64)
Requires:		perl(Module::Load)
Requires:       perl(Net::IPv6Addr)
Requires:		perl(Net::Ping)
Requires:		perl(Params::Validate)
Requires:		perl(Sys::Hostname)
Requires:		perl(Sys::Syslog)
Requires:		perl(Term::ReadKey)
Requires:		perl(Time::HiRes)
Requires:		perl(XML::LibXML) >= 1.60
Requires:	    perl-DBD-MySQL
Requires:	    mysql
Requires:	    mysql-server
Requires:	    libdbi-dbd-mysql
Requires:       perl-perfSONAR_PS-perfSONARBUOY-config

Requires:       chkconfig
Requires:       shadow-utils
Requires:       coreutils
Requires:       initscripts

%description server
The perfSONARBUOY server consists of the tools that interact with the database and collect measurements from local or remote beacons.

%package client
Summary:        perfSONAR_PS perfSONARBUOY Web Service Client and Measurement System
Group:          Applications/Network
Requires:		perl(Data::UUID)
Requires:       perl(Data::Validate::IP)
Requires:		perl(Digest::MD5)
Requires:		perl(Exporter)
Requires:		perl(File::Path)
Requires:		perl(FileHandle)
Requires:		perl(Getopt::Long)
Requires:		perl(Getopt::Std)
Requires:		perl(IO::File)
Requires:		perl(IO::Socket)
Requires:		perl(IPC::Open3)
Requires:		perl(LWP::UserAgent)
Requires:		perl(Log::Log4perl)
Requires:       perl(Net::IPv6Addr)
Requires:		perl(Params::Validate)
Requires:		perl(Sys::Syslog)
Requires:		perl(Time::HiRes)
Requires:		perl(XML::LibXML) >= 1.60
Requires:       perl-perfSONAR_PS-perfSONARBUOY-config
%description client
The perfSONARBUOY client conists of tools that perform measurements on the beacons as well as client applications that can interact with the web service.

%package config
Summary:        perfSONAR_PS perfSONARBUOY Configuration Information
Group:          Applications/Network
%description config
The perfSONARBUOY config package contains a configuration file that both the server and client packages require to operate.  

%pre server
/usr/sbin/groupadd perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%pre client
/usr/sbin/groupadd perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%pre config
/usr/sbin/groupadd perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%prep
%setup -q -n perfSONAR_PS-perfSONARBUOY-%{version}.%{relnum}

%build

%install
rm -rf $RPM_BUILD_ROOT

make ROOTPATH=$RPM_BUILD_ROOT/%{install_base} rpminstall

mkdir -p $RPM_BUILD_ROOT/etc/init.d

awk "{gsub(/^PREFIX=.*/,\"PREFIX=%{install_base}\"); print}" scripts/%{init_script_ma} > scripts/%{init_script_ma}.new
install -m 755 scripts/%{init_script_ma}.new $RPM_BUILD_ROOT/etc/init.d/%{init_script_ma}

awk "{gsub(/^PREFIX=.*/,\"PREFIX=%{install_base}\"); print}" scripts/%{init_script_bw_collector} > scripts/%{init_script_bw_collector}.new
install -m 755 scripts/%{init_script_bw_collector}.new $RPM_BUILD_ROOT/etc/init.d/%{init_script_bw_collector}

awk "{gsub(/^PREFIX=.*/,\"PREFIX=%{install_base}\"); print}" scripts/%{init_script_bw_master} > scripts/%{init_script_bw_master}.new
install -m 755 scripts/%{init_script_bw_master}.new $RPM_BUILD_ROOT/etc/init.d/%{init_script_bw_master}

awk "{gsub(/^PREFIX=.*/,\"PREFIX=%{install_base}\"); print}" scripts/%{init_script_owp_collector} > scripts/%{init_script_owp_collector}.new
install -m 755 scripts/%{init_script_owp_collector}.new $RPM_BUILD_ROOT/etc/init.d/%{init_script_owp_collector}

awk "{gsub(/^PREFIX=.*/,\"PREFIX=%{install_base}\"); print}" scripts/%{init_script_owp_master} > scripts/%{init_script_owp_master}.new
install -m 755 scripts/%{init_script_owp_master}.new $RPM_BUILD_ROOT/etc/init.d/%{init_script_owp_master}

%post server
mkdir -p /var/log/perfsonar
chown perfsonar:perfsonar /var/log/perfsonar

mkdir -p /var/lib/perfsonar/perfsonarbuoy_ma/bwctl
mkdir -p /var/lib/perfsonar/perfsonarbuoy_ma/owamp
chown -R perfsonar:perfsonar /var/lib/perfsonar

/sbin/chkconfig --add perfsonarbuoy_ma
/sbin/chkconfig --add perfsonarbuoy_bw_collector
/sbin/chkconfig --add perfsonarbuoy_owp_collector

%post client
mkdir -p /var/log/perfsonar
chown perfsonar:perfsonar /var/log/perfsonar

mkdir -p /var/lib/perfsonar/perfsonarbuoy_ma
chown -R perfsonar:perfsonar /var/lib/perfsonar

/sbin/chkconfig --add perfsonarbuoy_bw_master
/sbin/chkconfig --add perfsonarbuoy_owp_master

%post config

%clean
rm -rf $RPM_BUILD_ROOT

%files server
%defattr(-,perfsonar,perfsonar,-)
%doc %{install_base}/doc/*
%config(noreplace) %{install_base}/etc/daemon.conf
%config(noreplace) %{install_base}/etc/daemon_logger.conf
%{install_base}/bin/bwcollector.pl
%{install_base}/bin/powcollector.pl
%{install_base}/bin/configureDaemon.pl
%{install_base}/bin/makeDBConfig.pl
%{install_base}/bin/bwdb.pl
%{install_base}/bin/owdb.pl
%{install_base}/bin/daemon.pl
%{install_base}/scripts/install_dependencies.sh
%{install_base}/scripts/prepare_environment_server.sh
%{install_base}/scripts/perfsonarbuoy_ma
%{install_base}/scripts/perfsonarbuoy_bw_collector
%{install_base}/scripts/perfsonarbuoy_owp_collector
%{install_base}/lib/*
/etc/init.d/perfsonarbuoy_ma
/etc/init.d/perfsonarbuoy_bw_collector
/etc/init.d/perfsonarbuoy_owp_collector

%files client
%defattr(-,perfsonar,perfsonar,-)
%doc %{install_base}/doc/*
%config(noreplace) %{install_base}/etc/requests
%{install_base}/bin/client.pl
%{install_base}/bin/bwmaster.pl
%{install_base}/bin/powmaster.pl
%{install_base}/scripts/install_dependencies.sh
%{install_base}/scripts/prepare_environment_client.sh
%{install_base}/scripts/perfsonarbuoy_bw_master
%{install_base}/scripts/perfsonarbuoy_owp_master
%{install_base}/lib/*
/etc/init.d/perfsonarbuoy_bw_master
/etc/init.d/perfsonarbuoy_owp_master

%files config
%defattr(-,perfsonar,perfsonar,-)
%doc %{install_base}/doc/*
%config(noreplace) %{install_base}/etc/owmesh.conf

%preun server
if [ $1 -eq 0 ]; then
    /sbin/chkconfig --del perfsonarbuoy_ma
    /sbin/service perfsonarbuoy_ma stop
    /sbin/chkconfig --del perfsonarbuoy_bw_collector
    /sbin/service perfsonarbuoy_bw_collector stop
    /sbin/chkconfig --del perfsonarbuoy_owp_collector
    /sbin/service perfsonarbuoy_owp_collector stop
fi

%preun client

if [ $1 -eq 0 ]; then
    /sbin/chkconfig --del perfsonarbuoy_bw_master
    /sbin/service perfsonarbuoy_bw_master stop
    /sbin/chkconfig --del perfsonarbuoy_owp_master
    /sbin/service perfsonarbuoy_owp_master stop
fi

%changelog
* Mon May 17 2010 zurawski@internet2.edu 3.1-7
- Netlogger logging
- Updated request examples

* Tue Apr 27 2010 zurawski@internet2.edu 3.1-6
- Fixing a dependency problem with logging libraries

* Fri Apr 23 2010 zurawski@internet2.edu 3.1-5
- Documentation update
- Bugfixes
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=347
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=364
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=367
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=376
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=374
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=412
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=420
  
* Tue Sep 29 2009 zurawski@internet2.edu 3.1-4
- useradd option change
- Bugfixes
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=263
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=306
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=314
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=315
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=317

* Fri Sep 4 2009 zurawski@internet2.edu 3.1-3
- RPM generation error fixed

* Tue Aug 25 2009 zurawski@internet2.edu 3.1-2
- Fixes to to documentation and package structure.  
- Bugfixes
  - http://code.google.com/p/perfsonar-ps/issues/detail?id=241
  - http://code.google.com/p/perfsonar-ps/issues/detail?id=194
  - http://code.google.com/p/perfsonar-ps/issues/detail?id=192

* Tue Jul 21 2009 zurawski@internet2.edu 3.1-1
- Support for BWCTL and OWAMP regular testing
- Bugfixes
  - http://code.google.com/p/perfsonar-ps/issues/detail?id=185
  - http://code.google.com/p/perfsonar-ps/issues/detail?id=147
  
* Mon Feb 23 2009 zurawski@internet2.edu 0.10.4
- Fixing bug in bwmaster.

* Tue Jan 13 2009 zurawski@internet2.edu 0.10.3
- Fixing bug in bwcollector.

* Mon Jan 7 2009 zurawski@internet2.edu 0.10.2
- Adjustments to the required perl.

* Mon Jan 5 2009 zurawski@internet2.edu 0.10.1
- Initial file specification
