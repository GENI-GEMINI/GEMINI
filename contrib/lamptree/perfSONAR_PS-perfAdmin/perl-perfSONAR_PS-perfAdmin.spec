%define _unpackaged_files_terminate_build      0
%define install_base /opt/perfsonar_ps/perfAdmin

# cron/apache entry are located in the 'scripts' directory
%define crontab perfAdmin.cron
%define apacheconf perfAdmin.conf

%define relnum 9
%define disttag pSPS

Name:           perl-perfSONAR_PS-perfAdmin
Version:        3.1
Release:        %{relnum}.%{disttag}
Summary:        perfSONAR_PS perfAdmin
License:        distributable, see LICENSE
Group:          Development/Libraries
URL:            http://search.cpan.org/dist/perfSONAR_PS-perfAdmin
Source0:        perfSONAR_PS-perfAdmin-%{version}.%{relnum}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch
Requires:		perl(AnyEvent) >= 4.81
Requires:		perl(AnyEvent::HTTP)
Requires:		perl(CGI)
Requires:		perl(CGI::Carp)
Requires:		perl(Config::General)
Requires:		perl(Data::Dumper)
Requires:		perl(Data::Validate::Domain)
Requires:		perl(Data::Validate::IP)
Requires:		perl(Date::Manip)
Requires:		perl(Digest::MD5)
Requires:		perl(Exporter)
Requires:		perl(Getopt::Long)
Requires:		perl(HTML::Template)
Requires:		perl(IO::File)
Requires:		perl(LWP::Simple)
Requires:		perl(LWP::UserAgent)
Requires:		perl(Log::Log4perl)
Requires:		perl(Log::Dispatch)
Requires:		perl(Log::Dispatch::FileRotate)
Requires:		perl(Log::Dispatch::File)
Requires:		perl(Log::Dispatch::Syslog)
Requires:		perl(Log::Dispatch::Screen)
Requires:		perl(Net::CIDR)
Requires:		perl(Net::IPv6Addr)
Requires:		perl(Params::Validate)
Requires:		perl(Time::HiRes)
Requires:		perl(Time::Local)
Requires:		perl(XML::LibXML) >= 1.60
#Requires:       perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))
Requires:       perl
Requires:       httpd
%description
The perfSONAR-PS perfAdmin package is a series of simple web-based GUIs that interact with the perfSONAR Information Services (IS) to locate and display remote datasets.

%pre
/usr/sbin/groupadd perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%prep
%setup -q -n perfSONAR_PS-perfAdmin-%{version}.%{relnum}

%build

%install
rm -rf $RPM_BUILD_ROOT

make ROOTPATH=$RPM_BUILD_ROOT/%{install_base} rpminstall

mkdir -p $RPM_BUILD_ROOT/etc/cron.d

awk "{gsub(/^PREFIX=.*/,\"PREFIX=%{install_base}\"); print}" scripts/%{crontab} > scripts/%{crontab}.new
install -D -m 600 scripts/%{crontab}.new $RPM_BUILD_ROOT/etc/cron.d/%{crontab}

mkdir -p $RPM_BUILD_ROOT/etc/httpd/conf.d

awk "{gsub(/^PREFIX=.*/,\"PREFIX=%{install_base}\"); print}" scripts/%{apacheconf} > scripts/%{apacheconf}.new
install -D -m 644 scripts/%{apacheconf}.new $RPM_BUILD_ROOT/etc/httpd/conf.d/%{apacheconf}

%post
mkdir -p /var/log/perfsonar
chown perfsonar:perfsonar /var/log/perfsonar

mkdir -p /var/lib/perfsonar/perfAdmin/cache
chown -R perfsonar:perfsonar /var/lib/perfsonar/perfAdmin

chown -R apache:apache /opt/perfsonar_ps/perfAdmin/etc
chown -R root:root /etc/cron.d/perfAdmin.cron

/etc/init.d/crond restart
/etc/init.d/httpd restart

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,perfsonar,perfsonar,-)
%doc %{install_base}/doc/*
%config %{install_base}/etc/*
%{install_base}/bin/*
%{install_base}/cgi-bin/*
%{install_base}/scripts/*
%{install_base}/lib/*
/etc/cron.d/*
/etc/httpd/conf.d/*

%changelog
* Wed May 12 2010 zurawski@internet2.edu 3.1-9
- Including additions to make cache packages.  

* Tue Apr 27 2010 zurawski@internet2.edu 3.1-8
- Fixing a dependency problem with logging libraries

* Fri Apr 23 2010 zurawski@internet2.edu 3.1-7
- Documentation update
- Bugfixes
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=364
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=408
  
* Fri Oct 2 2009 zurawski@internet2.edu 3.1-6
- Install missing lib (lib/perfSONAR_PS/Datatypes/Message.pm)

* Tue Sep 28 2009 zurawski@internet2.edu 3.1-5
- useradd option change
- Bugfixes
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=323
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=317

* Fri Sep 4 2009 zurawski@internet2.edu 3.1-4
- RPM generation error fixed

* Mon Aug 24 2009 zurawski@internet2.edu 3.1-3
- Fixes to to documentation and package structure. 
- Adding new graph support for PingER
- Bugfixes
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=297
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=288
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=286
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=244
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=243
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=226
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=225

* Tue Jul 21 2009 zurawski@internet2.edu 3.1-2
- Bugfixes in several graphs.
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=143
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=141
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=136

* Thu Jul 9 2009 zurawski@internet2.edu 3.1-1
- Initial release as an RPM

