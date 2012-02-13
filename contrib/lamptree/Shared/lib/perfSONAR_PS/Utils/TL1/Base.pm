package perfSONAR_PS::Utils::TL1::Base;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Utils::TL1::Base

=head1 DESCRIPTION

A module that provides the Base from which all the TL1 modules derive. This
object is not meant to be used directly, but should be inherited by classes
that implement the various TL1 dialects.

=cut

use POSIX;
use Net::Telnet;
use Data::Dumper;
use Log::Log4perl qw(get_logger :nowarn);
use Carp;

use Params::Validate qw(:all);
use perfSONAR_PS::Utils::ParameterValidation;

use fields 'USERNAME', 'PASSWORD', 'TYPE', 'ADDRESS', 'PORT', 'CACHE_DURATION', 'CACHE_TIME', 'LOGGER', 'MACHINE_TIME', 'LOCAL_MACHINE_TIME', 'PROMPT', 'CTAG', 'TELNET', 'MESSAGES', 'STATUS', 'NODENAME';

=head2 new()

Allocates a new object.

=cut

sub new {
    my ( $class ) = @_;

    my $self = fields::new( $class );

    $self->{LOGGER} = get_logger( $class );

    return $self;
}

=head2 initialize({ type => 1, address => 1, port => 1, username => 1, password => 1, cache_time => 1, prompt => 1, ctag => 0)

Initializes the object according to the specified parameters. If the ctag is left unstated, it is randomly generated.

=cut

sub initialize {
    my ( $self, @params ) = @_;

    #my $parameters = validateParams(@params,
    my $parameters = validate(
        @params,
        {
            type       => 1,
            address    => 1,
            port       => 1,
            username   => 1,
            password   => 1,
            cache_time => 1,
            prompt     => 1,
            ctag       => 0,
        }
    );

    $self->{USERNAME} = $parameters->{username};
    $self->{PASSWORD} = $parameters->{password};
    $self->{TYPE}     = $parameters->{type};
    $self->{ADDRESS}  = $parameters->{address};
    $self->{PORT}     = $parameters->{port};
    $self->{PROMPT}   = $parameters->{prompt};
    $self->{MESSAGES} = ();

    if ( $parameters->{ctag} ) {
        $self->{CTAG} = $parameters->{ctag};
    }
    else {
        $self->{CTAG} = int( rand( 1000 ) );
    }

    $self->{STATUS} = "UNCONNECTED";

    $self->{CACHE_TIME}     = 0;
    $self->{CACHE_DURATION} = $parameters->{cache_time};

    return $self;
}

=head2 getType()

Returns the TL1 dialect of this object.

=cut

sub getType {
    my ( $self ) = @_;

    return $self->{TYPE};
}

=head2 getUsername()

Returns the username used to login to the TL1 device

=cut

sub getUsername {
    my ( $self ) = @_;

    return $self->{USERNAME};
}

=head2 getPassword()

Returns the password used to login to the TL1 device

=cut

sub getPassword {
    my ( $self ) = @_;

    return $self->{PASSWORD};
}

=head2 getAddress()

Returns the address of the TL1 device

=cut

sub getAddress {
    my ( $self ) = @_;

    return $self->{ADDRESS};
}

=head2 getCacheTime()
Returns the length of time that information is cached by the object
=cut

sub getCacheTime {
    my ( $self ) = @_;

    return $self->{CACHE_TIME};
}

=head2 login({ inhibit_messages })

Internal function used to login to the service. MAY be overridden by
implementing classes if they have special needs for logging in. If
inhibit_messages is set to true (the default), AS messages will be turned off
on login. If it is set to false, the connection will receive AS messages.

=cut

sub login {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { inhibit_messages => { type => SCALAR, optional => 1, default => 1 }, } );

    my ( $status, $lines ) = $self->send_cmd( "ACT-USER::" . $self->{USERNAME} . ":" . $self->{CTAG} . "::" . $self->{PASSWORD} . ";" );

    if ( $status != 1 ) {
        return 0;
    }

    if ( $parameters->{inhibit_messages} ) {
        $self->send_cmd( "INH-MSG-ALL:::" . $self->{CTAG} . ";" );
    }

    return 1;
}

=head2 logout()

Internal function used to logout of the service. CAN be overridden by
implementing class if more is required than just disconnecting from the machine.

=cut

sub logout {
    return;
}

=head2 connect({ inhibit_messages => 0 })

Connects and logs into the device. Returns 0 on success and -1 on failure. AS
messages can be disabled by setting the "inhibit_messages" key to 1.

=cut

sub connect {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { inhibit_messages => { type => SCALAR, optional => 1, default => 1 }, } );

    $self->{LOGGER}->info( "Connecting to " . $self->{ADDRESS} . ":" . $self->{PORT} );

    if ( not $self->{TELNET} = Net::Telnet->new( Host => $self->{ADDRESS}, Port => $self->{PORT}, Timeout => 15, Errmode => "return" ) ) {
        $self->{TELNET} = undef;
        return -1;
    }

    $self->{STATUS} = "LOGGING_IN";

    $self->{LOGGER}->info( "Logging into " . $self->{ADDRESS} );

    if ( not $self->login( { inhibit_messages => $parameters->{inhibit_messages} } ) ) {
        $self->{TELNET} = undef;
        $self->{STATUS} = "DISCONNECTED";
        return -1;
    }

    $self->{STATUS} = "CONNECTED";

    return 0;
}

=head2 disconnect({ })

Logs off and disconnects from the device. 

=cut

sub disconnect {
    my ( $self ) = @_;

    $self->{LOGGER}->info( "Disconnecting from " . $self->{ADDRESS} );

    $self->logout();

    $self->{MESSAGES} = ();

    if ( not $self->{TELNET} ) {
        return;
    }

    $self->{TELNET}->close;
    $self->{TELNET} = undef;

    $self->{STATUS} = "DISCONNECTED";

    return;
}

=head2 refresh_connection({ })

Keeps the connection alive by sending a PING-PONG like message to the device.

=cut

sub refresh_connection {
    my ( $self ) = @_;

    my ( $status, $res ) = $self->send_cmd( "RTRV-HDR:::" . $self->{CTAG} . ";" );
    if ( $status != 0 ) {
        return ( -1, $status );
    }

    return ( 0, q{} );
}

=head2 send_cmd($cmd)

Sends the specified command to the device and returns the response. It returns
(0, \@lines) where @lines is an array of the lines from the response. On error,
it will return (-1, [error msg]) where [error msg] is a string containing an
error message.

=cut

sub send_cmd {
    my ( $self, $cmd ) = @_;

    if ( not $self->{TELNET} ) {
        return ( -1, undef );
    }

    unless ( $self->{STATUS} eq "LOGGING_IN" or $self->{STATUS} eq "CONNECTED" ) {
        $self->{LOGGER}->error( "Invalid status: " . $self->{STATUS} );
        return ( -1, undef );
    }

    $self->{LOGGER}->debug( "Sending cmd: $cmd\n" );

    my $res;
    eval {
        $res = $self->{TELNET}->send( $cmd );
    };
    if ($@) {
        my $msg = "Send failed: ".$@;
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }

    my @retLines;
    my $successStatus;

    while ( not defined $successStatus ) {
        my ( $status, $lines ) = $self->waitMessage( { type => "response" } );

        # connection error
        if ( $status != 0 ) {
            $self->{LOGGER}->debug( "connection error" );
            return ( -1, undef );
        }

        # connection closed
        if ( not defined $lines ) {
            $self->{LOGGER}->debug( "connection closed" );
            return ( -1, undef );
        }

        @retLines = ();
        foreach my $line ( @{$lines} ) {

            next if ( $line =~ /$cmd/ );

            if ( $line =~ /([A-Z]+) (\d\d\d?\d?)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/ ) {
                $self->setMachineName( $1 );
                $self->setMachineTime( "$2-$3-$4 $5:$6:$7" );
                next;
            }
            elsif ( $line =~ /(\d\d\d?\d?)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/ ) {
                $self->setMachineTime( "$1-$2-$3 $4:$5:$6" );
                next;
            }
            elsif ( $line =~ /^\s*M\s+$self->{CTAG}\s+(COMPLD|DENY)/ ) {
                if ( $1 eq "COMPLD" ) {
                    $successStatus = 1;
                }
                elsif ( $1 eq "DENY" ) {
                    $successStatus = 0;
                }
            }
            else {
                push @retLines, $line;
            }
        }
    }

    return ( $successStatus, \@retLines );
}

=head2 waitMessage({ type => 1, timeout => 0 })

Waits for a message of the specified type from the device. The types are
specific to the class implementing the TL1 dialect. However, common ones are
"response", "alarm" and "event". The timeout parameter allows specifying how
many seconds to wait before returning an error message.

=cut

sub waitMessage {
    my ( $self, @args ) = @_;
    my $args = validateParams(
        @args,
        {
            type    => { type => SCALAR },
            timeout => { type => SCALAR, optional => 1 },
        }
    );

    my $type = $args->{type};

    $self->{LOGGER}->debug( "waitMessage: " . $type );

    my $end;
    if ( defined $args->{timeout} ) {
        $end = time + $args->{timeout};
    }

    if ( not defined $self->{MESSAGES}->{$type} ) {
        $self->{MESSAGES}->{$type} = ();
    }

    while ( $#{ $self->{MESSAGES}->{$type} } == -1 ) {
        my ( $status, $lines );

        if ( $end ) {
            my $timeout = $end - time;
            if ( $timeout <= 0 ) {
                $self->{LOGGER}->debug( "timeout occurred: " . ( $args->{timeout} ) );

                return ( 1, undef );
            }

            ( $status, $lines ) = $self->readMessage( { timeout => $timeout } );
        }
        else {
            ( $status, $lines ) = $self->readMessage();
        }

        if ( $status == -1 ) {
            $self->{LOGGER}->debug( "readMessage returned -1" );
            return ( -1, undef );
        }

        if ( $status == 0 and defined $lines ) {
            $self->processMessage( $lines );
            $self->{LOGGER}->debug( "Processed Message: " . Dumper( $self->{MESSAGES} ) );
        }
    }

    my $lines = shift( @{ $self->{MESSAGES}->{$type} } );

    return ( 0, $lines );
}

=head2 readMessage({ timeout => 0 })

Waits for any message from the device. Returns (0, \@lines) on success, (-1,
[error msg]) on error, (0, undef) if the connection closed and (1, undef) if a
timeout occurred.

=cut

sub readMessage {
    my ( $self, @args ) = @_;
    my $args = validateParams( @args, { timeout => { type => SCALAR, optional => 1 }, } );

    $self->{LOGGER}->debug( "readMessage" );

    if ( not $self->{TELNET} ) {
        $self->{LOGGER}->debug( "readMessage: no TELNET" );
        return ( -1, undef );
    }

    my ( $prematch, $prompt );
    if ( $args->{timeout} ) {
        ( $prematch, $prompt ) = $self->{TELNET}->waitfor(
            Match   => "/^" . $self->{PROMPT} . "/gm",
            Timeout => $args->{timeout},
            Errmode => "return",
        );
    }
    else {
        ( $prematch, $prompt ) = $self->{TELNET}->waitfor(
            Match   => "/^" . $self->{PROMPT} . "/gm",
            Errmode => "return",
        );
    }

    my $retStatus;

    if ( not defined $prematch ) {
        my $errmsg = $self->{TELNET}->errmsg();
        $self->{LOGGER}->debug( "Error message: $errmsg" );
        if ( $errmsg =~ /timed-out/ ) {
            $retStatus = 1;    # a timeout occurred.
        }
        elsif ( $errmsg =~ /read eof/ ) {
            $self->{LOGGER}->debug( "readMessage: read eof" );
            $retStatus = 0;    # connection closed.
        }
        else {
            $self->{LOGGER}->debug( "readMessage: other error: " . $errmsg );
            $retStatus = -1;    # an error occurred.
        }

        return ( $retStatus, undef );
    }
    else {
        $self->{LOGGER}->debug( "PREMATCH: " . $prematch . "\n" );

        my @lines = split( '\n', $prematch );
        return ( 0, \@lines );
    }
}

=head2 processMessage(\@lines)

An internal function which categorizes a message and then places it into a
buffer mailbox. As part of this, it also updates the internal machine time if
it sees a machine time.

=cut

sub processMessage {
    my ( $self, $lines ) = @_;

    $self->{LOGGER}->debug( "processMessage" );

    foreach my $line ( @{$lines} ) {
        $self->{LOGGER}->debug( "LINE: $line" );

        if ( $line =~ /(\d\d\d?\d?)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/ ) {
            $self->setMachineTime( "$1-$2-$3 $4:$5:$6" );
            last;
        }
    }

    my $type = $self->categorizeMessage( $lines );

    if ( not $type ) {
        return 0;
    }

    if ( not defined $self->{MESSAGES}->{$type} ) {
        $self->{MESSAGES}->{$type} = ();
    }

    push @{ $self->{MESSAGES}->{$type} }, $lines;

    return 0;
}

=head2 clearMessages()

Gets rid of all the queued up messages.

=cut

sub clearMessages {
    my ( $self ) = @_;

    $self->{MESSAGES} = ();

    return;
}

=head2 categorizeMessage()

Gets run against the message and decides what type that message is. This
version is a default, and handles categorizing messages as alarms, events,
responses or unknown.

=cut

sub categorizeMessage {
    my ( $self, $lines ) = @_;

    foreach my $line ( @{$lines} ) {
        if ( $line =~ /REPT ALM/ ) {
            $self->{LOGGER}->debug( "category: alarm" );

            return "alarm";
        }
        elsif ( $line =~ /REPT EVT/ ) {
            $self->{LOGGER}->debug( "category: event" );

            return "event";
        }
        elsif ( $line =~ /DENY/ or $line =~ /COMPLD/ ) {
            $self->{LOGGER}->debug( "category: response" );

            return "response";
        }
    }

    $self->{LOGGER}->debug( "category: other" );

    # return 'undef' to delete the message

    return "other";
}

=head2 setMachineName($name)

Internal function used to set the current machine name according to the name found in the machine.

=cut

sub setMachineName {
    my ( $self, $name ) = @_;

    $self->{NODENAME} = $name;

    return;
}

=head2 getMachineName()

Returns the machine's name as found during communication with the host. May be undefined.

=cut

sub getMachineName {
    my ( $self ) = @_;

    return $self->{NODENAME};
}

=head2 setMachineTime($time)

Internal function used to set the current machine time according to the times
seen on the machine.

=cut

sub setMachineTime {
    my ( $self, $time ) = @_;

    my ( $curr_date, $curr_time ) = split( " ", $time );
    my ( $year, $month,  $day )    = split( "-", $curr_date );
    my ( $hour, $minute, $second ) = split( ":", $curr_time );

    $self->{LOGGER}->debug( "Setting machine time: $year-$month-$day $hour:$minute:$second" );

    # make sure it's in 4 digit year form
    if ( length( $year ) == 2 ) {

        # I don't see why it'd ever not be +2000, but...
        if ( $year < 70 ) {
            $year += 100;
        }
    }
    else {
        $year -= 1900;
    }

    $month--;

    my $machine_ts = POSIX::mktime( $second, $minute, $hour, $day, $month, $year, 0, 0 );

    $self->{LOCAL_MACHINE_TIME} = time;
    $self->{MACHINE_TIME}       = $machine_ts;

    return;
}

=head2 getMachineTime()

Returns the current machine time, based on the last time the object saw from
the device, and what time it saw. Returns it as a human-readable string.

=cut

sub getMachineTime {
    my ( $self ) = @_;

    my $diff       = time - $self->{LOCAL_MACHINE_TIME};
    my $machine_ts = $self->{MACHINE_TIME} + $diff;

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime( $machine_ts );

    $mon++;
    $year += 1900;

    my $readable_time = sprintf( "%04d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec );

    #    $self->{LOGGER}->debug("Returning machine time: ".$readable_time."\n");

    return $readable_time;
}

=head2 getMachineTime_TS()

Returns the current machine time, based on the last time the object saw from
the device, and what time it saw. Returns it as a timestamp.

=cut

sub getMachineTime_TS {
    my ( $self ) = @_;

    my $diff       = time - $self->{LOCAL_MACHINE_TIME};
    my $machine_ts = $self->{MACHINE_TIME} + $diff;

    return $machine_ts;
}

=head2 convertPMDateTime()

Converts a performance-metric date/time into an absolute data/time. The PM
date/time don't inclue a year, so this attemps to guess it based on the
device's time.

=cut

sub convertPMDateTime {
    my ( $self, $date, $time ) = @_;

    # guess the year of the interval based on the current machine time
    my ( $month,       $day )         = split( '-', $date );
    my ( $hour,        $minute )      = split( '-', $time );
    my ( $switch_date, $switch_time ) = split( ' ', $self->getMachineTime() );

    my ( $switch_year, $switch_month,  $switch_day )    = split( '-', $switch_date );
    my ( $switch_hour, $switch_minute, $switch_second ) = split( ':', $switch_time );

    # Calculate the year
    my $year;

    if ( $switch_month eq $month ) {
        $year = $switch_year;
    }
    elsif ( $switch_month ne $month ) {
        if ( $switch_month == 1 ) {
            $year = $switch_year - 1;
        }
        else {
            $year = $switch_year;
        }
    }

    return sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year, $month, $day, $hour, $minute, 0;
}

=head2 convertTimeStringToTimestamp()

Internal function that converts a time string into a unix timestamp.

=cut

sub convertTimeStringToTimestamp {
    my ( $self, $time_str ) = @_;

    # guess the year of the interval based on the current machine time
    my ( $date, $time ) = split( ' ', $time_str );

    my ( $year, $month,  $day )    = split( '-', $date );
    my ( $hour, $minute, $second ) = split( ':', $time );

    return POSIX::mktime( $second, $minute, $hour, $day, $month - 1, $year - 1900, 0, 0 );
}

=head2 convertMachineTSToLocalTS()

Function that maps a machine timestamp to a local timestamp. Used if the
machine is not synchronized with NTP.

=cut

sub convertMachineTSToLocalTS {
    my ( $self, $machine_timestamp ) = @_;

    my $diff = $self->{MACHINE_TIME} - $self->{LOCAL_MACHINE_TIME};

    return $machine_timestamp + $diff;
}

1;

__END__

=head1 SEE ALSO

L<POSIX>, L<Net::Telnet>, L<Log::Log4perl>,
L<perfSONAR_PS::Utils::ParameterValidation>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Base.pm 3658 2009-08-28 11:40:19Z aaron $

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2008-2009, Internet2

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
