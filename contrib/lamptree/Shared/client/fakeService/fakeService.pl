#!/usr/bin/perl -w

use warnings;
use strict;

use lib "../../lib";

use perfSONAR_PS::Client::LS;
use Config::General qw(ParseConfig SaveConfig);
use Data::Random::WordList;
use Getopt::Long;

=head1 NAME

fakeService.pl - Emulate a service registering to an LS/hLS instance.

=head1 DESCRIPTION

Emulate a service registering to an LS/hLS instance.  The
original purpose was to test summarization of the data, but benchmarking
performance is also a possibility.  This file uses a configuration file
(fakeService.conf) and will generate it's own with some simple questions if
not present.  

=cut

my $DEBUG = '';
my $HELP = '';
my $MUNGE = '';
my %opts = ();
GetOptions('verbose' => \$DEBUG,
           'help' => \$HELP,
           'config=s' => \$opts{CONF},
           'list=s' => \$opts{WLIST},
           'munge' => \$MUNGE);

if(!(defined $opts{CONF} or defined $opts{WLIST}) or $HELP) {
  print "$0: Runs fakeService with configuration file CONFIG\n";
  print "$0 [--verbose --help --list=/usr/share/dict/words --config=/path/to/config/file]\n";
  exit(1);
}

# 0-2 = 33% odds of switching the SNMP Subject/EventType
my $subjectOdds = 2;

# 0-2 = 33% - odds of NOT using a subnet, 66% of using one
my $subnetOdds = 2;
my @subnets = ( "cs", "it", "cis", "eecis", "oit", "cse" );

# subnet monkey business, we will generate somwhere between 5 and 10 each time
my $numC    = int rand(5) + 5;
my @cClass  = ();
my %service = ();

my $file = "./fakeService.conf";
my $wordList = "/usr/share/dict/words";
if(defined $opts{CONF}) {
  $file = $opts{CONF};
}
if(defined $opts{WLIST}) {
  $wordList = $opts{WLIST};
}

my %config = ();
if ( -f $file ) {
    %config = ParseConfig($file);
}
else {

    # get some questions answered

    $config{"domain"}      = getWord(1, $wordList);
    $config{"ip"}          = getIP(1);
    $config{"type"}        = &ask( "Enter the service type ( snmp | pSB | dcn )", "snmp", $config{"type"}, '(snmp|pSB|dcn)' );
    $config{"md_number"}   = &ask( "Enter the number of metadata ", "10", $config{"md_number"}, '\d+' );
    $config{"keywords"}        = &ask( "Enter any service keywords separated by commas (ex: LHC,Internet2)", "LHC", $config{"keywords"}, '.*' );
    $config{"ls"}          = &ask( "Enter the hLS to register with ", "http://localhost:8080/perfSONAR_PS/services/gLS", $config{"ls"}, '^http:\/\/' );
    $config{"ls_interval"} = &ask( "Enter the hLS registration interval (in minutes) ", "1", $config{"ls_interval"}, '\d+' );
    $config{"ls_interval"} *= 60;
    SaveConfig_mine( $file, \%config );
}

my @metadataArray = ();
if ( $config{"type"} eq "snmp" ) {

    @cClass = ();
    for my $num ( 0 .. $numC ) {
        push @cClass, ( int rand(253) + 1 );
    }

    %service = (
        serviceName        => $config{"domain"} . " SNMP MA",
        serviceType        => "MA",
        serviceDescription => "A fake " . "SNMP MA deployed at " . $config{"domain"},
        accessPoint        => "http://" . getWord(0, $wordList) . "." . $config{"domain"} . ":" . ( int rand(8192) + 1024 ) . "/perfSONAR_PS/services/snmpMA"
    );

    for my $id ( 1 .. ( int( $config{"md_number"} / 2 ) ) ) {

        my $type = int rand($subjectOdds);
        my $host = getWord(0, $wordList);
        my $sub  = int rand($subnetOdds);
        if ($sub) {
            $sub = int rand( $#subnets - 1 );
        }

        my $address = $config{"ip"};
        my $c       = $cClass[ int rand( $#cClass - 1 ) ];
        my $d       = int rand(253) + 1;
        $address =~ s/c/$c/;
        $address =~ s/d/$d/;

        for my $id2 ( 0 .. 1 ) {

            my $metadata = "    <nmwg:metadata xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"metadata." . $id . "_" . $id2 . "\">\n";

            if ( $type == 0 ) {
                $metadata .= "      <netutil:subject xmlns:netutil=\"http://ggf.org/ns/nmwg/characteristic/utilization/2.0/\" id=\"subject." . $id . "_" . $id2 . "\">\n";
            }
            elsif ( $type == 1 ) {
                $metadata .= "      <netdisc:subject xmlns:netdisc=\"http://ggf.org/ns/nmwg/characteristic/discards/2.0/\" id=\"subject." . $id . "_" . $id2 . "\">\n";
            }
            else {
                $metadata .= "      <neterr:subject xmlns:neterr=\"http://ggf.org/ns/nmwg/characteristic/errors/2.0/\" id=\"subject." . $id . "_" . $id2 . "\">\n";
            }
            $metadata .= "        <nmwgt:interface xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";
            $metadata .= "          <nmwgt:ifAddress type=\"ipv4\">" . $address . "</nmwgt:ifAddress>\n";

            if ( $sub ) {
                $metadata .= "          <nmwgt:hostName>" . $host . "." . $subnets[$sub] . "." . $config{"domain"} . "</nmwgt:hostName>\n";
            }
            else {
                $metadata .= "          <nmwgt:hostName>" . $host . "." . $config{"domain"} . "</nmwgt:hostName>\n";
            }

            $metadata .= "          <nmwgt:ifName>eth" . $id . "</nmwgt:ifName>\n";
            $metadata .= "          <nmwgt:ifIndex>" . $id . "</nmwgt:ifIndex>\n";
            if ( $id2 == 0 ) {
                $metadata .= "          <nmwgt:direction>in</nmwgt:direction>\n";
            }
            else {
                $metadata .= "          <nmwgt:direction>out</nmwgt:direction>\n";
            }
            $metadata .= "          <nmwgt:capacity>1000000000</nmwgt:capacity>\n";
            $metadata .= "        </nmwgt:interface>\n";
            if ( $type == 0 ) {
                $metadata .= "      </netutil:subject>\n";
                $metadata .= "      <nmwg:eventType>http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:eventType>\n";
                $metadata .= "      <nmwg:eventType>http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:eventType>\n";
                $metadata .= "      <nmwg:parameters id=\"parameters." . $id . "_" . $id2 . "\">\n";
                $metadata .= "        <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:parameter>\n";
                $metadata .= "        <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:parameter>\n";
            }
            elsif ( $type == 1 ) {
                $metadata .= "      </netdisc:subject>\n";
                $metadata .= "      <nmwg:eventType>http://ggf.org/ns/nmwg/characteristic/discards/2.0</nmwg:eventType>\n";
                $metadata .= "      <nmwg:eventType>http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:eventType>\n";
                $metadata .= "      <nmwg:parameters id=\"parameters." . $id . "_" . $id2 . "\">\n";
                $metadata .= "        <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/characteristic/discards/2.0</nmwg:parameter>\n";
                $metadata .= "        <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:parameter>\n";
            }
            else {
                $metadata .= "      </neterr:subject>\n";
                $metadata .= "      <nmwg:eventType>http://ggf.org/ns/nmwg/characteristic/errors/2.0</nmwg:eventType>\n";
                $metadata .= "      <nmwg:eventType>http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:eventType>\n";
                $metadata .= "      <nmwg:parameters id=\"parameters." . $id . "_" . $id2 . "\">\n";
                $metadata .= "        <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/characteristic/errors/2.0</nmwg:parameter>\n";
                $metadata .= "        <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:parameter>\n";
            }
            
            my @k_array = split(/,/, $config{"keywords"});
            foreach my $k ( @k_array ) {
              $k =~ s/(\s|\n)*//g;
              $metadata .= "        <nmwg:parameter name=\"keyword\">project:".$k."</nmwg:parameter>\n";
            }            

            $metadata .= "      </nmwg:parameters>\n";
            $metadata .= "    </nmwg:metadata>\n";

            push @metadataArray, $metadata;
        }
    }
}
elsif ( $config{"type"} eq "pSB" ) {

    # set up the Service info...

    %service = (
        serviceName        => $config{"domain"} . " perfSONAR-BUOY MA",
        serviceType        => "MA",
        serviceDescription => "A fake " . "perfSONAR-BUOY MA deployed at " . $config{"domain"},
        accessPoint        => "http://" . getWord(0, $wordList) . "." . $config{"domain"} . ":" . ( int rand(8192) + 1024 ) . "/perfSONAR_PS/services/pSB"
    );

    for my $id ( 1 .. ( int( $config{"md_number"} / 2 ) ) ) {

        @cClass = ();
        for my $num ( 0 .. $numC ) {
            push @cClass, ( int rand(253) + 1 );
        }

        my $host1;
        my $sub = int rand($subnetOdds);
        if ($sub) {
            $sub   = int rand( $#subnets - 1 );
            $host1 = getWord(0, $wordList) . "." . $subnets[$sub] . "." . $config{"domain"};
        }
        else {
            $host1 = getWord(0, $wordList) . "." . $config{"domain"};
        }

        my $host2;
        my $domain2 = getWord(1, $wordList);
        $sub = int rand($subnetOdds);
        if ($sub) {
            $sub   = int rand( $#subnets - 1 );
            $host2 = getWord(0, $wordList) . "." . $subnets[$sub] . "." . $domain2;
        }
        else {
            $host2 = getWord(0, $wordList) . "." . $domain2;
        }

        my $address1 = $config{"ip"};
        my $c        = $cClass[ int rand( $#cClass - 1 ) ];
        my $d        = int rand(253) + 1;
        $address1 =~ s/c/$c/;
        $address1 =~ s/d/$d/;

        my $address2 = getIP();
        $c = $cClass[ int rand( $#cClass - 1 ) ];
        $d = int rand(253) + 1;
        $address2 =~ s/c/$c/;
        $address2 =~ s/d/$d/;

        if ( ( ( int rand(100) ) % 2 ) == 0 ) {
            for my $id2 ( 0 .. 1 ) {
                my $metadata = "    <nmwg:metadata xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"metadata." . $id . "\" >\n";
                $metadata .= "      <owamp:subject xmlns:owamp=\"http://ggf.org/ns/nmwg/tools/owamp/2.0/\" id=\"subject." . $id . "\" >\n";
                $metadata .= "        <nmwgt:endPointPair xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";
                if ( $id2 == 0 ) {
                    $metadata .= "          <nmwgt:src type=\"ipv4\" value=\"" . $address1 . "\" />\n";
                    $metadata .= "          <nmwgt:dst type=\"ipv4\" value=\"" . $address2 . "\" />\n";
                }
                else {
                    $metadata .= "          <nmwgt:src type=\"hostname\" value=\"" . $host1 . "\" />\n";
                    $metadata .= "          <nmwgt:dst type=\"hostname\" value=\"" . $host2 . "\" />\n";
                }
                $metadata .= "        </nmwgt:endPointPair>\n";
                $metadata .= "      </owamp:subject>\n";
                $metadata .= "      <nmwg:eventType>http://ggf.org/ns/nmwg/tools/owamp/2.0</nmwg:eventType>\n";
                $metadata .= "      <nmwg:eventType>http://ggf.org/ns/nmwg/characteristic/delay/summary/20070921</nmwg:eventType>\n";

                $metadata .= "      <nmwg:parameters id=\"parameters." . $id . "\" >\n";
                my @k_array = split(/,/, $config{"keywords"});
                foreach my $k ( @k_array ) {
                  $k =~ s/(\s|\n)*//g;
                  $metadata .= "        <nmwg:parameter name=\"keyword\">project:".$k."</nmwg:parameter>\n";
                }            
                $metadata .= "      </nmwg:parameters>\n";

                $metadata .= "    </nmwg:metadata>\n";
                push @metadataArray, $metadata;
            }
        }
        else {
            for my $id2 ( 0 .. 1 ) {
                my $metadata = "    <nmwg:metadata xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"metadata." . $id . "\" >\n";
                $metadata .= "      <iperf:subject xmlns:iperf=\"http://ggf.org/ns/nmwg/tools/iperf/2.0/\" id=\"subject." . $id . "\" >\n";
                $metadata .= "        <nmwgt:endPointPair xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";
                if ( $id2 == 0 ) {
                    $metadata .= "          <nmwgt:src type=\"ipv4\" value=\"" . $address1 . "\" />\n";
                    $metadata .= "          <nmwgt:dst type=\"ipv4\" value=\"" . $address2 . "\" />\n";
                }
                else {
                    $metadata .= "          <nmwgt:src type=\"hostname\" value=\"" . $host1 . "\" />\n";
                    $metadata .= "          <nmwgt:dst type=\"hostname\" value=\"" . $host2 . "\" />\n";
                }
                $metadata .= "        </nmwgt:endPointPair>\n";
                $metadata .= "      </iperf:subject>\n";
                $metadata .= "      <nmwg:eventType>http://ggf.org/ns/nmwg/tools/iperf/2.0</nmwg:eventType>\n";
                $metadata .= "      <nmwg:eventType>http://ggf.org/ns/nmwg/characteristics/bandwidth/acheiveable/2.0</nmwg:eventType>\n";
                $metadata .= "      <nmwg:parameters id=\"parameters." . $id . "\" >\n";
                $metadata .= "        <nmwg:parameter name=\"windowSize\">1m</nmwg:parameter>\n";
                $metadata .= "        <nmwg:parameter name=\"bufferLength\">500</nmwg:parameter>\n";
                $metadata .= "        <nmwg:parameter name=\"timeDuration\">6</nmwg:parameter>\n";
                $metadata .= "        <nmwg:parameter name=\"interval\">2</nmwg:parameter>\n";
                $metadata .= "        <nmwg:parameter name=\"protocol\">UDP</nmwg:parameter>\n";
                $metadata .= "        <nmwg:parameter name=\"bandwidthLimit\">5m</nmwg:parameter>\n";
  
                my @k_array = split(/,/, $config{"keywords"});
                foreach my $k ( @k_array ) {
                  $k =~ s/(\s|\n)*//g;
                  $metadata .= "        <nmwg:parameter name=\"keyword\">project:".$k."</nmwg:parameter>\n";
                }            

                $metadata .= "      </nmwg:parameters>\n";
                $metadata .= "    </nmwg:metadata>\n";
                push @metadataArray, $metadata;
            }
        }
    }
}
elsif ( $config{"type"} eq "dcn" ) {

    # set up the Service info...

    %service = (
        serviceName        => "DCN LS",
        serviceType        => "LS",
        accessPoint        => $config{"ls"}
    );

    @cClass = ();
    for my $num ( 0 .. $numC ) {
        push @cClass, ( int rand(253) + 1 );
    }

    for my $id ( 1 .. $config{"md_number"} ) {


        my $host1;
        my $sub = int rand($subnetOdds);
        if ($sub) {
            $sub   = int rand( $#subnets - 1 );
            $host1 = $subnets[$sub] . "." . $config{"domain"};
        }
        else {
            $host1 = $config{"domain"};
        }

        my $address1 = $config{"ip"};
        my $c        = $cClass[ int rand( $#cClass - 1 ) ];
        my $d        = int rand(253) + 1;
        $address1 =~ s/c/$c/;
        $address1 =~ s/d/$d/;

        my $urn = "urn:ogf:network:domain=".$host1.":node=".getWord(0, $wordList).":port=".( int ( rand(65536) + 1 ) ).":link=".$address1;

        my $host2;
        $sub = int rand($subnetOdds);
        if ($sub) {
            $sub   = int rand( $#subnets - 1 );
            $host2 = getWord(0, $wordList) . "." . $subnets[$sub] . "." . getWord(0, $wordList) . ".edu";
        }
        else {
            $host2 = getWord(0, $wordList) . "." . getWord(0, $wordList) . ".edu";
        }
        my $friendlyName = $host2;

        my $metadata = "    <nmwg:metadata xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"metadata." . $id . "\" >\n";
        $metadata .= "      <dcn:subject xmlns:dcn=\"http://ggf.org/ns/nmwg/tools/dcn/2.0/\" id=\"subject." . $id . "\" >\n";
        $metadata .= "        <nmtb:node xmlns:nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\" id=\"node.".$id."\">\n";
        $metadata .= "          <nmtb:address type=\"hostname\">".$friendlyName."</nmtb:address>\n";
        $metadata .= "          <nmtb:relation type=\"connectionLink\">\n";
        $metadata .= "            <nmtb:linkIdRef>".$urn."</nmtb:linkIdRef>\n";
        $metadata .= "          </nmtb:relation>\n";
        $metadata .= "        </nmtb:node>\n";
        $metadata .= "      </dcn:subject>\n";
        $metadata .= "      <nmwg:eventType>http://oscars.es.net/OSCARS</nmwg:eventType>\n";
        $metadata .= "    </nmwg:metadata>\n";
        push @metadataArray, $metadata;        
    }
}

my $ls = new perfSONAR_PS::Client::LS( { instance => $config{"ls"} } );
my $result = q{};

if ( $config{"key"} ) {
    $result = $ls->deregisterRequestLS( { key => $config{"key"} } );
    if ( exists $result->{eventType} and $result->{eventType} eq "success.ls.deregister" ) {
        print "Service successfully deregistered\n";
    }
    else {
        print "Service deregistration failed";
        if (exists $result->{eventType} and exists $result->{response} ) {
            print " - eventType:\t" . $result->{eventType} . "\nResponse:\t" . $result->{response};
        }
        else {
            print " - LS did not respond.";
        }    
        print "\n";
    }
}

my $first = 1;
while (1) {
    if ($first) {
        $result = $ls->registerRequestLS( { service => \%service, data => \@metadataArray } );
        if ( exists $result->{eventType} and $result->{eventType} eq "success.ls.register" ) {
            $config{"key"} = $result->{key};
            print "Success!  The key is \"" . $config{"key"} . "\"\n";
            print "Message:\t" . $result->{response} . "\n";
            SaveConfig_mine( $file, \%config );
            $first--;
        }
        else {
            print "Service failed to register";
            if (exists $result->{eventType} and exists $result->{response} ) {
                print " - eventType:\t" . $result->{eventType} . "\nResponse:\t" . $result->{response};
            }
            else {
                print " - LS did not respond.";
            }
            print "\n";
        }
    }
    else {
        if ( $MUNGE ) {
            $result = $ls->deregisterRequestLS( { key => $config{"key"} } );
            if ( exists $result->{eventType} and $result->{eventType} eq "success.ls.deregister" ) {
                print "Service successfully deregistered\n";
            }
            else {
                print "Service deregistration failed";
                if (exists $result->{eventType} and exists $result->{response} ) {
                    print " - eventType:\t" . $result->{eventType} . "\nResponse:\t" . $result->{response};
                }
                else {
                    print " - LS did not respond.";
                }    
                print "\n";
            }
        }
        
        $result = $ls->keepaliveRequestLS( { key => $config{"key"} } );
        if ( exists $result->{eventType} and $result->{eventType} eq "success.ls.keepalive" ) {
            print "Success!\n";
            print "Message:\t" . $result->{response} . "\n";
        }
        else {
            print "Service failed to keepalive";
            if (exists $result->{eventType} and exists $result->{response} ) {
                print " - eventType:\t" . $result->{eventType} . "\nResponse:\t" . $result->{response};
            }
            else {
                print " - LS did not respond.";
            }
            print "\n";
            $result = $ls->registerRequestLS( { service => \%service, data => \@metadataArray } );
            if ( exists $result->{eventType} and $result->{eventType} eq "success.ls.register" ) {
                $config{"key"} = $result->{key};
                print "Success!  The key is \"" . $config{"key"} . "\"\n";
                print "Message:\t" . $result->{response} . "\n";
                SaveConfig_mine( $file, \%config );
            }
            else {
                print "Service failed to register";
                if (exists $result->{eventType} and exists $result->{response} ) {
                    print " - eventType:\t" . $result->{eventType} . "\nResponse:\t" . $result->{response};
                }
                else {
                    print " - LS did not respond.";
                }
                print "\n";
            }
        }
    }

    print "Sleeping for ", $config{"ls_interval"} / 60, " minutes...\n";
    sleep( $config{"ls_interval"} );
}

=head2 getIP()

  Return a class B address with some markers for C and D.
  
=cut

sub getIP {
    return ( join ".", map int rand 254, 1 .. 2 ) . ".c.d";
}

=head2 getWord( $domain )

  Return a random word that doesn't contain any punctuation marks.
  
=cut

sub getWord {
    my ($domain, $wordList) = @_;
    my $wl = new Data::Random::WordList( wordlist => $wordList );

    my $d = 0;
    while ( not $d ) {
        my @domain = $wl->get_words(1);
        
        my $okChar = '-a-zA-Z0-9\s';
        $domain[0] =~  s/[^$okChar]//go;
        if ($domain) {
            $wl->close();
            return lc( $domain[0] ) . ".edu";
        }
        else {
            $wl->close();
            return lc( $domain[0] );
        }
    }
}

=head2 ask( $prompt, $value, $prev_value, $regex )

  Prompt for configuration values.
  
=cut

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

=head2 SaveConfig_mine( $file, $hash )

  Save the configuration file.
  
=cut

sub SaveConfig_mine {
    my ( $file, $hash ) = @_;

    my $fh;

    if ( open( $fh, ">", $file ) ) {
        printValue( $fh, q{}, $hash, -4 );
        if ( close($fh) ) {
            return 0;
        }
    }
    return -1;
}

=head2 printSpaces( $fh, $count )

  Print some number of spaces.
  
=cut

sub printSpaces {
    my ( $fh, $count ) = @_;
    while ( $count > 0 ) {
        print $fh " ";
        $count--;
    }
    return;
}

=head2 printScalar( $fileHandle, $name, $value, $depth )

  Given a scalar configuration value, print this out.
  
=cut

sub printScalar {
    my ( $fileHandle, $name, $value, $depth ) = @_;

    printSpaces( $fileHandle, $depth );
    if ( $value =~ /\n/mx ) {
        my @lines = split( $value, '\n' );
        print $fileHandle "$name     <<EOF\n";
        foreach my $line (@lines) {
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

=head2 printValue( $fileHandle, $name, $value, $depth )

  Given some configuration value, print out the structure for the
  configuration file.
  
=cut

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
            if ($name) {
                printSpaces( $fileHandle, $depth );
                print $fileHandle "<$name>\n";
            }
            foreach my $elm ( sort keys %{$value} ) {
                printValue( $fileHandle, $elm, $value->{$elm}, $depth + 4 );
            }
            if ($name) {
                printSpaces( $fileHandle, $depth );
                print $fileHandle "</$name>\n";
            }
        }

        return;
    }
}

__END__

=head1 SEE ALSO

L<perfSONAR_PS::Client::LS>, L<Config::General>, L<Data::Random::WordList>,
L<Getopt::Long>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS

Questions and comments can be directed to the author, or the mailing list.  Bugs,
feature requests, and improvements can be directed here:

  https://bugs.internet2.edu/jira/browse/PSPS

=head1 VERSION

$Id: fakeService.pl 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework along
with this software.  If not, see <http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2008, Internet2

All rights reserved.

=cut
