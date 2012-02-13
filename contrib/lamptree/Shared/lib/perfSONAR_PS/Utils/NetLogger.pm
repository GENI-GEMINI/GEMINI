package perfSONAR_PS::Utils::NetLogger;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME
     
perfSONAR_PS::Utils::NetLogger
    
=head1 DESCRIPTION

A module that provides tools to generate NetLogger formatted messages for
log4perl.  For more information on NetLogger see: 

http://dsd.lbl.gov/NetLoggerWiki/index.php/Main_Page

=head1 API
    
The API of NetLogger is used to format log messages in the NetLogger 'Best
Practices' format. See: http://www.cedps.net/wiki/index.php/LoggingBestPractices
    
=cut

require 5.002;
use Time::HiRes;
use Data::UUID;

# initialize Global GUID
my $GUID = get_guid();

=head2 format("event_name", list of name=>value pairs)

Sample use:

  use Log::Log4perl qw(:easy);
  use NetLogger;
  Log::Log4perl->easy_init($DEBUG);

  my $logger = get_logger("my_prog");

  $logger->info(NetLogger::format("org.perfsonar.client.parseResults.start"));
  # call function here
  $logger->info(NetLogger::format("org.perfsonar.client.parseResults.end", {val=>12,}));
  

This will generate a log that looks like this:

2007/12/19 13:51:26 39899 INFO> myprog:NN main:: - ts=2007-12-19T21:51:26.030823Z \
	event=org.perfsonar.client.runQuery1.end guid=736ee764-ae7c-11dc-9f7d-000f1f6ed15d

=cut

sub format {
    my ( $evnt, $data ) = @_;
    my ( $str ) = q{};
    if ( exists $data->{'ts'} ) {
        $str = "ts=$data->{ 'ts' } ";
    }
    else {
        my $dt = date();
        $str = "ts=$dt ";
    }
    $str .= "event=$evnt ";
    foreach my $k ( keys %$data ) {
        $str .= "$k=$data->{$k} ";
    }
    $str .= "guid=" . $GUID;
    return $str;
}

=head2 date

TBD

=cut

sub date {
    my ( $tm, $usec ) = Time::HiRes::gettimeofday();
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = gmtime( $tm );
    return sprintf( "%04d-%02d-%02dT%02d:%02d:%02d.%06dZ", $year + 1900, $mon + 1, $mday, $hour, $min, $sec, $usec );
}

=head2 get_guid

TBD

=cut

sub get_guid {
    my $ug   = new Data::UUID;
    my $guid = $ug->create_str();

    # if dont have Data::UUID, can do this instead
    #  my $guid = `uuidgen`; chomp $guid;

    return ( $guid );
}

=head2 reset_guid

TBD

=cut

sub reset_guid {
    my $ug = new Data::UUID;
    $GUID = $ug->create_str();

    # if dont have Data::UUID, can do this instead
    #  my $GUID = `uuidgen`; chomp $GUID;

    return;
}

1;

__END__

=head1 SEE ALSO

L<Time::HiRes>, L<Data::UUID>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: NetLogger.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Dan Gunter, dkgunter@lbl.gov

=head1 LICENSE

See: http://dsd.lbl.gov/NetLoggerWiki/index.php/Licensing

=head1 COPYRIGHT

Copyright (c) 2004-2007, Internet2, Lawrenence Berkeley National Lab, and the
University of California.

All rights reserved.

=cut
