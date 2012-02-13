package perfSONAR_PS::Client::OSCARS;

use strict;
use warnings;

our $VERSION = 3.1;

use fields 'LOGGER', 'IDC_URL', 'CLIENT_DIR', 'AXIS2_DIR';

=head1 NAME

perfSONAR_PS::Client::OSCARS

=head1 DESCRIPTION

Utilities for interacting with the OSCARS software.

=cut

use IO::Handle;
use Cwd;
use Log::Log4perl qw(get_logger);

use OSCARS::listReservationsResponse;
use perfSONAR_PS::Utils::ParameterValidation;

=head2 new($package)

Create a new object.

=cut

sub new {
        my ($class) = @_;

        my $self = fields::new($class);

        $self->{LOGGER} = get_logger($class);

        return $self;
}

sub init {
    my ($self, @params) = @_;
    my $parameters = validateParams( @params, { oscars_client => 1, axis2_home => 1, idc_url => 1 } );

    unless ($parameters->{oscars_client}) {
        $self->{LOGGER}->error("Must specify directory location of the OSCARS Notification client");
        return -1;
    }

    if (not $parameters->{axis2_home} and not $ENV{"AXIS2_HOME"}) {
        $self->{LOGGER}->error("Must specify directory location of the OSCARS Notification client");
        return -1;
    }

    if ($parameters->{axis2_home}) {
        $self->{AXIS2_DIR} = $parameters->{axis2_home};
    } else {
        $self->{AXIS2_DIR} = $ENV{"AXIS2_HOME"};
    }

    $self->{CLIENT_DIR} = $parameters->{oscars_client};
    $self->{IDC_URL}    = $parameters->{idc_url};

    return 0;
}

=head2 getClasspath

Get the class path to pass to java.

=cut
sub getClasspath {
    my ($self) = @_;

    my $classpath = ".";

    if (!defined $self->{AXIS2_DIR} or $self->{AXIS2_DIR} eq "") {
	    my $msg = "Environmental variable AXIS2_HOME undefined";
	    $self->{LOGGER}->error($msg);
    	return (-1, $msg);;
    }

    my $dir = $self->{AXIS2_DIR}."/lib";

    opendir(DIR, $dir);
    while((my $entry = readdir(DIR))) {
        if ($entry =~ /\.jar$/) {
            $classpath .= ":$dir/$entry";
        }
    }
    closedir(DIR);
    $classpath .= ":".$self->{CLIENT_DIR}."/examples/OSCARS-client-examples.jar";
    $classpath .= ":".$self->{CLIENT_DIR}."/OSCARS-client-api.jar";
    $classpath .= ":".$self->{CLIENT_DIR}."/lib/jdom.jar";
    $classpath .= ":".$self->{CLIENT_DIR}."/lib/perfsonar.jar";

    return (0, $classpath);
}

=head2 listReservations( $self )

Get list of circuits from the IDC.

=cut

sub listReservations {
    my ($self, @params) = @_;
    my $parameters = validateParams( @params, { start_time => 0, end_time => 0, max_reservations => 0, status => 0 });

    my $prev_dir = cwd;

    chdir( $self->{CLIENT_DIR}."/examples" );

    my ( $status, $classpath ) = $self->getClasspath();
    if ( $status == -1 ) {
        my $msg = "Couldn't find classpath: $classpath";
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }

    my $repo_dir = $self->{CLIENT_DIR} . "/examples/conf/axis-tomcat";

    my $output = "";
    my $cmd = "java -cp $classpath -Djava.net.preferIPv4Stack=true ListReservationCLI -repo $repo_dir -url " . $self->{IDC_URL} . " -raw";
    $cmd .= " -startTime ".$parameters->{start_time} if ($parameters->{start_time});
    $cmd .= " -endTime ".$parameters->{end_time} if ($parameters->{end_time});
    $cmd .= " -status ".$parameters->{status} if ($parameters->{status});
    if (defined $parameters->{max_reservations}) {
        $cmd .= " -numresults ".$parameters->{max_reservations};
    }
    else {
        $cmd .= " -numresults 0";
    }

    my $stime_exec = time;
    $self->{LOGGER}->debug("running $cmd from ".cwd);
    open(EXEC, "-|", $cmd);
    while(<EXEC>) {
        $output .= $_;
    }
    close(EXEC);
    my $etime_exec = time;

    chdir( $prev_dir );

    unless ($output) {
        my $msg = "Error running client: no output";
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }

    my $stime_parse = time;
    my $parser = XML::LibXML->new();
    my $doc = $parser->parse_string($output);
    my $xpath_context = XML::LibXML::XPathContext->new();
    $xpath_context->registerNs("oscars", "http://oscars.es.net/OSCARS");

    my $response_node;
    eval{
        $response_node = $xpath_context->find("//oscars:listReservationsResponse", $doc)->get_node(1)
    };
    if ($@) {
        my $msg = "Couldn't parse result: ".$@;
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }
    my $etime_parse = time;

    my $stime_parse_2 = time;
    my $response = OSCARS::listReservationsResponse->from_xml_dom($response_node);
    my $etime_parse_2 = time;

    $self->{LOGGER}->debug("Time to query: ".($etime_exec - $stime_exec));
    $self->{LOGGER}->debug("Time to parse: ".($etime_parse - $stime_parse));
    $self->{LOGGER}->debug("Time to parse DOM: ".($etime_parse_2 - $stime_parse_2));

    return (0, $response);
}

1;

__END__

=head1 SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: OSCARS.pm 2845 2009-06-25 18:00:28Z aaron $

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
