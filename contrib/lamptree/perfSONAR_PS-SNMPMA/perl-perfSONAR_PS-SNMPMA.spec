%define _unpackaged_files_terminate_build      0
Autoreq: 0 

%define install_base /opt/perfsonar_ps/snmp_ma

# init scripts must be located in the 'scripts' directory
%define init_script_1 snmp_ma

%define relnum 11
%define disttag pSPS

Name:           perl-perfSONAR_PS-SNMPMA
Version:        3.1
Release:        %{relnum}.%{disttag}
Summary:        perfSONAR_PS SNMP Measurement Archive
License:        distributable, see LICENSE
Group:          Development/Libraries
URL:            http://search.cpan.org/dist/perfSONAR_PS-SNMPMA
Source0:        perfSONAR_PS-SNMPMA-%{version}.%{relnum}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch
Requires:		perl(Clone)
Requires:		perl(Compress::Zlib)
Requires:		perl(Config::General)
Requires:		perl(Cwd)
Requires:		perl(DBI)
Requires:		perl(Date::Format)
Requires:		perl(Date::Parse)
Requires:		perl(Data::UUID)
Requires:		perl(Date::Manip)
Requires:		perl(Digest::MD5)
Requires:		perl(Email::Date::Format)
Requires:		perl(Error)
Requires:		perl(Error::Simple)
Requires:		perl(Exporter)
Requires:		perl(File::Basename)
Requires:		perl(File::Temp)
Requires:		perl(Getopt::Long)
Requires:		perl(HTML::Entities)
Requires:		perl(HTML::Tagset)
Requires:		perl(HTTP::Daemon)
Requires:		perl(IO::File)
Requires:		perl(IPC::Shareable)
Requires:		perl(LWP::Simple)
Requires:		perl(LWP::UserAgent)
Requires:		perl(Log::Log4perl)
Requires:		perl(Log::Dispatch)
Requires:		perl(Log::Dispatch::FileRotate)
Requires:		perl(Log::Dispatch::File)
Requires:		perl(Log::Dispatch::Syslog)
Requires:		perl(Log::Dispatch::Screen)
Requires:		perl(Log::Log4perl)
Requires:		perl(Mail::Sender)
Requires:		perl(Mail::Sendmail)
Requires:		perl(Mail::Send)
Requires:		perl(MIME::Lite)
Requires:		perl(Module::Load)
Requires:		perl(Net::Daemon)
Requires:		perl(Net::Daemon::Log)
Requires:		perl(Net::Daemon::Test)
Requires:		perl(Net::Ping)
Requires:		perl(Params::Validate)
Requires:		perl(RPC::PlServer)
Requires:		perl(RPC::PlClient)
Requires:		perl(RRDp)
Requires:		perl(Sys::Hostname)
Requires:		perl(Time::HiRes)
Requires:		perl(URI)
Requires:		perl(URI::Escape)
Requires:		perl(URI::Heuristic)
Requires:		perl(URI::URL)
Requires:		perl(XML::DOM)
Requires:		perl(XML::LibXML) >= 1.60
Requires:		perl(XML::LibXML::Common)
Requires:		perl(XML::NamespaceSupport)
Requires:		perl(XML::RegExp)
Requires:		perl(XML::SAX::DocumentLocator)
Requires:		perl(XML::SAX::Base)
Requires:		perl(XML::SAX::Exception)
#Requires:       perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))
Requires:       	perl
Requires:		rrdtool
Requires:		rrdtool-perl
Requires:		coreutils
Requires:		which
Requires:		shadow-utils
Requires:		chkconfig

%description
The perfSONAR-PS SNMP MA is a measurement archive that is able to deliver gathered SNMP data (from tools such as Cricket/MRTG/Cacti) through a web services interface.  This particular version depends on RRDtool and related libaries to read the underlying data.    

%pre
/usr/sbin/groupadd perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%prep
%setup -q -n perfSONAR_PS-SNMPMA-%{version}.%{relnum}

%build

%install
rm -rf $RPM_BUILD_ROOT

make ROOTPATH=$RPM_BUILD_ROOT/%{install_base} rpminstall

mkdir -p $RPM_BUILD_ROOT/etc/init.d

awk "{gsub(/^PREFIX=.*/,\"PREFIX=%{install_base}\"); print}" scripts/%{init_script_1} > scripts/%{init_script_1}.new
install -D -m 755 scripts/%{init_script_1}.new $RPM_BUILD_ROOT/etc/init.d/%{init_script_1}

%post
mkdir -p /var/log/perfsonar
chown perfsonar:perfsonar /var/log/perfsonar

mkdir -p /var/lib/perfsonar/snmp_ma
if [ ! -f /var/lib/perfsonar/snmp_ma/store.xml ];
then
	%{install_base}/scripts/makeStore.pl /var/lib/perfsonar/snmp_ma 1
fi
chown -R perfsonar:perfsonar /var/lib/perfsonar

/sbin/chkconfig --add snmp_ma

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,perfsonar,perfsonar,-)
%doc %{install_base}/doc/*
%config %{install_base}/etc/*
%{install_base}/bin/*
%{install_base}/scripts/*
%{install_base}/lib/*
/etc/init.d/*

%preun
if [ $1 -eq 0 ]; then
    /sbin/chkconfig --del snmp_ma
    /sbin/service snmp_ma stop
fi

%changelog
* Tue Apr 27 2010 zurawski@internet2.edu 3.1-11
- Fixing a dependency problem with logging libraries

* Fri Apr 23 2010 zurawski@internet2.edu 3.1-10
- Documentation update
- Bugfixes
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=340
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=4

* Tue Sep 29 2009 zurawski@internet2.edu 3.1-9
- useradd option change
- Bugfixes
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=279
 - http://code.google.com/p/perfsonar-ps/issues/detail?id=215

* Fri Sep 4 2009 zurawski@internet2.edu 3.1-8
- RPM generation error fixed

* Tue Aug 25 2009 zurawski@internet2.edu 3.1-7
- Fixes to to documentation and package structure.  

* Tue Jul 21 2009 zurawski@internet2.edu 3.1-6
- Shared library upgrades.

* Fri Jul 10 2009 zurawski@internet2.edu 3.1-5
- Documentation updates

* Mon Jul 6 2009 zurawski@internet2.edu 3.1-4
- Bugfix
  - http://code.google.com/p/perfsonar-ps/issues/detail?id=187

* Thu May 16 2009 zurawski@internet2.edu 3.1-3
- Bugfix
  - http://code.google.com/p/perfsonar-ps/issues/detail?id=159

* Tue Apr 21 2009 zurawski@internet2.edu 3.1-2
- Bugfix to the RRD.pm library

* Mon Mar 16 2009 zurawski@internet2.edu 3.1-1
- Initial release as an RPM
