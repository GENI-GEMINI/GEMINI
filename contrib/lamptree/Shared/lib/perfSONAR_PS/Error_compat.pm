package perfSONAR_PS::Error_compat;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Error_compat

=head1 DESCRIPTION

A module that provides a transition between a full on exceptions framework for
perfSONAR PS and having each service specify explicitly the eventType and
description.  This module provides a simple method for throwing exceptions that
look similar to how eventType/description messages used to be propogated.

=cut

use base 'Error';

my $debug = 0;

sub new {
    my $self      = shift;
    my $eventType = shift;
    my $text      = shift;

    my @args = ();
    local $Error::Debug = 1 if $debug;
    local $Error::Depth = $Error::Depth + 1;

    my $obj = $self->SUPER::new( -text => $text, @args );

    $obj->{EVENT_TYPE} = $eventType;

    return $obj;
}

sub eventType {
    my $self = shift;

    return $self->{EVENT_TYPE};
}

sub errorMessage {
    my $self = shift;

    return $self->text();
}

1;

__END__

=head1 SYNOPSIS

  # if an error occurs, perfSONAR_PS objects should throw an error eg
  sub openDB {
    my $handle = undef;
    $handle = DBI->connect( ... )
  	  or throw perfSONAR_PS::Error_compat( "error.common.storage", "Could not connect to database: " . $DBI::errstr . "\n" );
  	return $handle;
  }

  ### script.pl ###
  
  # in the calling code
  my $dbh = undef;
  try {
  
    $dbh = &openDB();
  
  }
  catch perfSONAR_PS::Error_compat with {
  
    # print the contents of the error object (the string)
    print "An error occur: ".$@->eventType."/".$@->errorMessage."\n";
  
  }
  otherwise {
  
    # some other error occured!
    print "Some unknown error occurred! $@\n";
  
  }
  finally {
  
    print "Done!\n"'
  
  }; 
  
  # don't forget the trailing ';'

=head1 SEE ALSO

L<perfSONAR_PS::Services::Base>, L<perfSONAR_PS::Services::MA::General>, L<perfSONAR_PS::Common>,
L<perfSONAR_PS::Messages>, L<perfSONAR_PS::Transport>,
L<perfSONAR_PS::Client::Status::MA>, L<perfSONAR_PS::Client::Topology::MA>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Error_compat.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE
 
You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT
 
Copyright (c) 2004-2009, Internet2 and the University of Delaware

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
