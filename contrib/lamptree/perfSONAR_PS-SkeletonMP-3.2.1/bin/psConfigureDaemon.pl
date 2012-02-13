#!/usr/bin/perl -w -I ./lib ../lib

#use strict;
use warnings;
use Config::General qw(ParseConfig SaveConfig);
use Sys::Hostname;
use English qw( -no_match_vars );
use Module::Load;
use File::Temp qw(tempfile);
use Term::ReadKey;
use Cwd;

=head1 NAME

psConfigureDaemon - Ask a series of questions to generate a configuration file.

=head1 DESCRIPTION

Ask questions based on a service to generate a configuration file.

=cut

my $dirname = getcwd . "/";
unless ( $dirname =~ m/scripts\/$/ ) {
    $dirname .= "scripts/";
}

my $was_installed = 0;
my $DEFAULT_FILE;
my $confdir;

if ( $was_installed ) {
    $confdir = "XXX_CONFDIR_XXX";
}
else {
    $confdir = getcwd;
}

$DEFAULT_FILE = $confdir . "/daemon.conf";

print " -- perfSONAR-PS Daemon Configuration --\n";
print " - [press enter for the default choice] -\n\n";

my $file = shift;

unless ( $file ) {
    $file = &ask( "What file should I write the configuration to? ", $DEFAULT_FILE, undef, '.+' );
}

my $tmp;
our $default_hostname = hostname();
our $hostname         = 'localhost';
our $db_name          = q{};
our $db_port          = q{};
our $db_username      = 'dbuser';
our $db_password      = 'dbpass';

my %config = ();
if ( -f $file ) {
    %config = ParseConfig( $file );
}

# make sure all the endpoints start with a "/".
if ( defined $config{"port"} ) {
    foreach my $port ( keys %{ $config{"port"} } ) {
        if ( exists $config{"port"}->{$port}->{"endpoint"} ) {
            foreach my $endpoint ( keys %{ $config{"port"}->{$port}->{"endpoint"} } ) {
                my $new_endpoint = $endpoint;

                if ( $endpoint =~ /^[^\/]/mx ) {
                    $new_endpoint = "/" . $endpoint;
                }

                if ( $endpoint ne $new_endpoint ) {
                    $config{"port"}->{$port}->{"endpoint"}->{$new_endpoint} = $config{"port"}->{$port}->{"endpoint"}->{$endpoint};
                    delete( $config{"port"}->{$port}->{"endpoint"}->{$endpoint} );
                }
            }
        }
    }
}

while ( 1 ) {
    my $input;
    print "1) Set global values\n";
    print "2) Add/Edit endpoint\n";
    print "3) Enable/Disable port/endpoint\n";
    print "4) Save configuration\n";
    print "5) Exit\n";
    $input = &ask( "? ", q{}, undef, '[12345]' );

    if ( $input == 5 ) {
        exit( 0 );
    }
    elsif ( $input == 4 ) {
        if ( -f $file ) {
            system( "mv $file $file~" );
        }

        SaveConfig_mine( $file, \%config );
        print "\n";
        print "Saved config to $file\n";
        print "\n";
    }
    elsif ( $input == 1 ) {
        $config{"max_worker_processes"}     = &ask( "Enter the maximum number of children processes (0 means infinite) ",                   "30",                                                       $config{"max_worker_processes"},     '^\d+$' );
        $config{"max_worker_lifetime"}      = &ask( "Enter number of seconds a child can process before it is stopped (0 means infinite) ", "300",                                                      $config{"max_worker_lifetime"},      '^\d+$' );
        $config{"disable_echo"}             = &ask( "Disable echo by default (0 for no, 1 for yes) ",                                       0,                                                          $config{"disable_echo"},             '^[01]$' );
        $config{"ls_instance"}              = &ask( "The LS for MAs to register with ",                                                     "http://ndb1.internet2.edu:9995/perfSONAR_PS/services/hLS", $config{"ls_instance"},              '(^http|^$)' );
        $config{"ls_registration_interval"} = &ask( "Interval between when LS registrations occur [in minutes] ",                           60,                                                         $config{"ls_registration_interval"}, '^\d+$' );
        $config{"root_hints_url"}           = &ask( "URL of the root.hints file ",                                                          "http://www.perfsonar.net/gls.root.hints",                  $config{"root_hints_url"},           '(^http|^$)' );
        $config{"root_hints_file"}          = &ask( "Where shold the root.hints file be stored ",                                           $confdir . "/gls.root.hints",                               $config{"root_hints_file"},          '^\/' );
        $config{"reaper_interval"}          = &ask( "Interval between when children are repeaed [in seconds] ",                             20,                                                         $config{"reaper_interval"},          '^\d+$' );
        $config{"pid_dir"}                  = &ask( "Enter pid dir location ",                                                              "/var/run",                                                 $config{"pid_dir"},                  q{} );
        $config{"pid_file"}                 = &ask( "Enter pid filename ",                                                                  "ps.pid",                                                   $config{"pid_file"},                 q{} );
    }
    elsif ( $input == 3 ) {
        my @elements = ();
        my %status   = ();

        foreach my $port ( sort keys %{ $config{"port"} } ) {
            next unless ( exists $config{"port"}->{$port}->{"endpoint"} );
            push @elements, $port;

            if ( exists $config{"port"}->{$port}->{"disabled"} and $config{"port"}->{$port}->{"disabled"} == 1 ) {
                $status{$port} = 1;
            }
        }

        foreach my $port ( sort keys %{ $config{"port"} } ) {
            next unless ( exists $config{"port"}->{$port}->{"endpoint"} );
            foreach my $endpoint ( sort keys %{ $config{"port"}->{$port}->{"endpoint"} } ) {
                push @elements, "$port$endpoint";
                if ( exists $config{"port"}->{$port}->{"endpoint"}->{$endpoint}->{"disabled"}
                    and $config{"port"}->{$port}->{"endpoint"}->{$endpoint}->{"disabled"} == 1 )
                {
                    $status{"$port$endpoint"} = 1;
                }
            }
        }

        if ( $#elements > -1 ) {
            print "\n";
            print "Select element to enable/disable: \n";
            my $len = $#elements;
            for my $i ( 0 .. $len ) {
                print " $i) $elements[$i] ";
                print " *" if exists $status{ $elements[$i] };
                print "\n";
            }
            print "\n";
            print " * element is disabled\n";
            print "\n";

            do {
                $input = &ask( "Select a number from the above ", q{}, undef, '^\d+$' );
            } while ( $input > $#elements );

            my $new_status;

            if ( exists $status{ $elements[$input] } ) {
                $new_status = 0;
            }
            else {
                $new_status = 1;
            }

            print "\n";
            if ( $new_status ) {
                print "Disabling";
            }
            else {
                print "Enabling";
            }

            if ( $elements[$input] =~ /^(\d+)(\/.*)$/mx ) {
                print " endpoint " . $elements[$input] . "\n";
                $config{"port"}->{$1}->{"endpoint"}->{$2}->{"disabled"} = $new_status;
            }
            elsif ( $elements[$input] =~ /^(\d+)$/mx ) {
                print " port " . $elements[$input] . "\n";
                $config{"port"}->{$1}->{"disabled"} = $new_status;
            }
            print "\n";
        }
    }
    elsif ( $input == 2 ) {
        my @endpoints = ();
        foreach my $port ( sort keys %{ $config{"port"} } ) {
            next unless ( exists $config{"port"}->{$port}->{"endpoint"} );
            foreach my $endpoint ( sort keys %{ $config{"port"}->{$port}->{"endpoint"} } ) {
                push @endpoints, "$port$endpoint";
            }
        }

        if ( $#endpoints > -1 ) {
            print "\n";
            print "Existing Endpoints: \n";
            my $len = $#endpoints;
            for my $i ( 0 .. $len ) {
                print " $i) $endpoints[$i]\n";
            }
            print "\n";
        }

        do {
            $input = &ask( "Enter endpoint in form 'port/endpoint_path' (e.g. 8080/perfSONAR_PS/services/SERVICE_NAME) or select from a number from the above ", q{}, undef, '^(\d+[\/].*|\d+)$' );
            if ( $input =~ /^\d+$/mx ) {
                $input = $endpoints[$input];
            }
        } while ( not( $input =~ /\d+[\/].*/mx ) );

        my ( $port, $endpoint );
        if ( $input =~ /(\d+)([\/].*)/mx ) {
            $port     = $1;
            $endpoint = $2;
        }

        unless ( exists $config{"port"} ) {
            my %hash = ();
            $config{"port"} = \%hash;
        }

        unless ( exists $config{"port"}->{$port} ) {
            my %hash = ();
            $config{"port"}->{$port} = \%hash;
            $config{"port"}->{$port}->{"endpoint"} = ();
        }

        unless ( exists $config{"port"}->{$port}->{"endpoint"}->{$endpoint} ) {
            $config{"port"}->{$port}->{"endpoint"}->{$endpoint} = ();
        }

        my $valid_module = 0;
        my $module       = $config{"port"}->{$port}->{"endpoint"}->{$endpoint}->{"module"};
        if ( defined $module ) {
            if ( $module eq "perfSONAR_PS::Services::MP::Skeleton" ) {
                $module = "skeleton";
            }
        }

        my %opts;
        do {
            $module = &ask( "Enter endpoint module [skeleton] ", q{}, $module, q{} );
            $module = lc( $module );

            if ( $module eq "skeleton" ) {
                $valid_module = 1;
            }
        } while ( $valid_module == 0 );

        unless ( $hostname ) {
            $hostname = &ask( "Enter the external host or IP for this machine ", $hostname, $default_hostname, '.+' );
        }

        my $accesspoint = &ask( "Enter the accesspoint for this service ", "http://$hostname:$port$endpoint", undef, '^http' );

        if ( $module eq "skeleton" ) {
            $config{"port"}->{$port}->{"endpoint"}->{$endpoint}->{"module"} = "perfSONAR_PS::Services::MP::Skeleton";
            config_snmp_ma( $config{"port"}->{$port}->{"endpoint"}->{$endpoint}, $accesspoint, \%config );
        }
    }
}

sub config_snmp_ma {
    my ( $config, $accesspoint, $def_config ) = @_;

    $config->{"skeleton"} = () unless exists $config->{"skeleton"};
    my @result = ();
    $config->{"skeleton"}->{"metadata_db_external"} = "none";
    my $makeStore = &ask( "Automatically generate a 'test' metadata database (0 for no, 1 for yes) ", "0", "0", '^[01]$' );
    if ( $makeStore ) {
        my $RUN = q{};
        open( $RUN, "perl ../scripts/makeStore.pl " . $confdir . " |" );
        @result = <$RUN>;
        close( $RUN );
        unless ( $result[0] ) {
            return -1;
        }
    }

    $config->{"skeleton"}->{"metadata_db_type"} = "file";

    delete $config->{"skeleton"}->{"metadata_db_file"} if $config->{"skeleton"}->{"metadata_db_file"} and $config->{"skeleton"}->{"metadata_db_file"} =~ m/dbxml$/mx;
    $config->{"skeleton"}->{"metadata_db_file"} = &ask( "Enter the filename of the XML file ", $confdir . "/snmp-store.xml", $config->{"skeleton"}->{"metadata_db_file"}, '\.xml$' );
    if ( $result[0] ) {
        if ( -f $config->{"skeleton"}->{"metadata_db_file"} ) {
            system( "mv " . $config->{"skeleton"}->{"metadata_db_file"} . " " . $config->{"skeleton"}->{"metadata_db_file"} . "~" );
        }
        system( "mv " . $result[0] . " " . $config->{"skeleton"}->{"metadata_db_file"} );
    }
    delete $config->{"skeleton"}->{"db_autoload"}               if $config->{"skeleton"}->{"db_autoload"};
    delete $config->{"skeleton"}->{"autoload_metadata_db_file"} if $config->{"skeleton"}->{"autoload_metadata_db_file"};
    delete $config->{"skeleton"}->{"metadata_db_name"}          if $config->{"skeleton"}->{"metadata_db_name"};

    $config->{"skeleton"}->{"data_file"} = &ask( "Enter the filename of the data file ", $confdir . "/data", $config->{"skeleton"}->{"data_file"}, '.+' );

    $config->{"skeleton"}->{"maintenance_interval"} = &ask( "Interval between when service maintenance occurs [in seconds] ", "60", $registration_interval, '^\d+$' );

    $config->{"skeleton"}->{"collection_interval"} = &ask( "Interval between when measurement collection occurs [in seconds] ", "5", $registration_interval, '^\d+$' );

    $config->{"skeleton"}->{"enable_registration"} = &ask( "Will this service register with an LS (0 for no, 1 for yes)", "0", $config->{"skeleton"}->{"enable_registration"}, '^[01]$' );
    my $registration_interval = $def_config->{"ls_registration_interval"};
    $registration_interval = $config->{"skeleton"}->{"ls_registration_interval"} if exists $config->{"skeleton"}->{"ls_registration_interval"};
    my $ls_instance = $def_config->{"ls_instance"};
    $ls_instance = $config->{"skeleton"}->{"ls_instance"} if exists $config->{"skeleton"}->{"ls_instance"};
    if ( $config->{"skeleton"}->{"enable_registration"} eq "1" ) {
        $config->{"skeleton"}->{"ls_registration_interval"} = &ask( "Interval between when LS registrations occur [in minutes] ", "30", $registration_interval, '^\d+$' );
        $config->{"skeleton"}->{"ls_instance"} = &ask( "URL of an LS to register with ", q{}, $ls_instance, '^http:\/\/' );
    }
    else {
        $config->{"skeleton"}->{"ls_instance"}              = $ls_instance           if $ls_instance;
        $config->{"skeleton"}->{"ls_registration_interval"} = $registration_interval if $registration_interval;
    }

    $config->{"skeleton"}->{"service_name"} = &ask( "Enter a name for this service ", "Skeleton MP", $config->{"skeleton"}->{"service_name"}, '.+' );

    $config->{"skeleton"}->{"service_type"} = &ask( "Enter the service type ", "MP", $config->{"skeleton"}->{"service_type"}, '.+' );

    $config->{"skeleton"}->{"service_description"} = &ask( "Enter a service description ", "Skeleton MP", $config->{"skeleton"}->{"service_description"}, '.+' );

    $config->{"skeleton"}->{"service_accesspoint"} = &ask( "Enter the service's URI ", $accesspoint, $config->{"skeleton"}->{"service_accesspoint"}, '^http:\/\/' );

    return;
}

sub ask {
    my ( $prompt, $value, $prev_value, $regex ) = @_;

    my $result;
    do {
        print $prompt;
        if ( defined $prev_value ) {
            print "[", $prev_value, "]";
        }
        elsif ( defined $value ) {
            print "[", $value, "]";
        }
        print ": ";
        local $| = 1;

        local $_ = <STDIN>;
        chomp;
        if ( defined $_ and $_ ne q{} ) {
            $result = $_;
        }
        elsif ( defined $prev_value ) {
            $result = $prev_value;
        }
        elsif ( defined $value ) {
            $result = $value;
        }
        else {
            $result = q{};
        }
    } while ( $regex and ( not $result =~ /$regex/mx ) );

    return $result;
}

sub SaveConfig_mine {
    my ( $file, $hash ) = @_;

    my $fh;

    if ( open( $fh, ">", $file ) ) {
        printValue( $fh, q{}, $hash, -4 );
        if ( close( $fh ) ) {
            return 0;
        }
    }
    return -1;
}

sub printSpaces {
    my ( $fh, $count ) = @_;
    while ( $count > 0 ) {
        print $fh " ";
        $count--;
    }
    return;
}

sub printScalar {
    my ( $fileHandle, $name, $value, $depth ) = @_;

    printSpaces( $fileHandle, $depth );
    if ( $value =~ /\n/mx ) {
        my @lines = split( $value, '\n' );
        print $fileHandle "$name     <<EOF\n";
        foreach my $line ( @lines ) {
            printSpaces( $fileHandle, $depth );
            print $fileHandle $line . "\n";
        }
        printSpaces( $fileHandle, $depth );
        print $fileHandle "EOF\n";
    }
    else {
        print $fileHandle "$name     " . $value . "\n";
    }
    return;
}

sub printValue {
    my ( $fileHandle, $name, $value, $depth ) = @_;

    if ( ref $value eq "" ) {
        printScalar( $fileHandle, $name, $value, $depth );

        return;
    }
    elsif ( ref $value eq "ARRAY" ) {
        foreach my $elm ( @{$value} ) {
            printValue( $fileHandle, $name, $elm, $depth );
        }

        return;
    }
    elsif ( ref $value eq "HASH" ) {
        if ( $name eq "endpoint" or $name eq "port" ) {
            foreach my $elm ( sort keys %{$value} ) {
                printSpaces( $fileHandle, $depth );
                print $fileHandle "<$name $elm>\n";
                printValue( $fileHandle, q{}, $value->{$elm}, $depth + 4 );
                printSpaces( $fileHandle, $depth );
                print $fileHandle "</$name>\n";
            }
        }
        else {
            if ( $name ) {
                printSpaces( $fileHandle, $depth );
                print $fileHandle "<$name>\n";
            }
            foreach my $elm ( sort keys %{$value} ) {
                printValue( $fileHandle, $elm, $value->{$elm}, $depth + 4 );
            }
            if ( $name ) {
                printSpaces( $fileHandle, $depth );
                print $fileHandle "</$name>\n";
            }
        }

        return;
    }
}

__END__
	
=head1 SEE ALSO

L<Config::General>, L<Sys::Hostname>, L<Data::Dumper>

To join the 'perfSONAR Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id$

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu
Aaron Brown, aaron@internet2.edu
Guilherme Fernandes, fernande@cis.udel.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2010, Internet2 and the University of Delaware

All rights reserved.

=cut
