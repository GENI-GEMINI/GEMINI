package perfSONAR_PS::XML::Base;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::XML::Base 

=head1 DESCRIPTION

A module that provides basic methods for the creation of perfSONAR XML
fragments.  The purpose of this module simplify the creation of valid XML for
the various perfSONAR_PS services.

=head1 API

=cut

use perfSONAR_PS::XML::Namespace;
use Log::Log4perl qw(get_logger);

@ISA    = ( 'Exporter' );
@EXPORT = qw( createEndPointL4 createSubjectL4 createSubjectL3 createParameters );

our $logger = &get_logger( "perfSONAR_PS::XML::Base" );

=head2 createEndPointL4( $doc, $ns, $hash, $role, $protocol )

Creates the following LibXML fragment:

  <nmwgt:endPoint role="src" protocol="icmp">
    <nmwgt:interface>
      <nmwgt:ifHostName>iepm-bw.slac.stanford.edu<nmwgt:ifHostName>
      <nmwgt:ipAddress>134.79.240.38</nmwgt:ipAddress>
    </nmwgt:interface>
  </nmwgt:endPoint>

Where $doc is the libXML document class, $ns is a hash of namespace references, $role is either
'src' or 'dst' and protocol is 'icmp' or 'tcp' or 'udp'. The $hash input is a assoc. hash of key, 
value pairs that will be inserted as children of the 'interface' element as tagname textContent() 
pairs.

=cut

sub createEndPointL4 {
    my $doc = shift;
    my $ns  = shift;    # perfsonarps::xml::namespace object

    my $hash = shift;   # hash of key=element tag, value=text value pairs

    my $role     = shift;
    my $protocol = shift;

    #$logger->debug( "creating source" );
    my $endPoint = $doc->createElement( 'endPoint' );

    $endPoint->setNamespace( $ns->getNsByKey( 'nmwgt' ), 'nmwgt' );
    $endPoint->setAttribute( 'role',     $role )     if defined $role;
    $endPoint->setAttribute( 'protocol', $protocol ) if defined $protocol;

    my $interface = $doc->createElement( 'interface' );
    $interface->setNamespace( $ns->getNsByKey( 'nmwgt' ), 'nmwgt' );
    $endPoint->appendChild( $interface );

    while ( my ( $k, $v ) = each %$hash ) {
        my $key = $doc->createElement( $k );
        $key->setNamespace( $ns->getNsByKey( 'nmwgt' ), 'nmwgt' );    #TODO!
        my $text = XML::LibXML::Text->new( $v );
        $key->appendChild( $text );

        $interface->appendChild( $key );
    }

    return $endPoint;
}

=head2 createSubjectL4( $doc, $ns, $baseNS, $protocol, $source, $dest, $sourceIP, $destIP )

Creates the subject XML fragment as follows:

    <pinger:subject id="pingsubject--slac.stanford.edu--frcu.eun.eg" 
      <nmtl4:endPointPair>
        <nmtl4:endPoint role="src" protocol="icpm">
          <nmtl3:interface id="#d1">
            <nmtl3:ifHostName>iepm-bw.slac.stanford.edu"</nmtl3:ifHostName>     
            <nmtl3:ipAddress>134.79.240.38</nmtl3:ipAddress>   
          </nmtl3:interface>
        </nmtl4:endPoint>
        <nmtl4:endPoint role="dst" protocol="icpm">
          <nmtl3:interface id="#a1">
            <nmtl3:ifHostName>atlang-hstnng.abilene.ucaid.edu</nmtl3:ifHostName>
            <nmtl3:ipAddress>"198.32.8.34</nmtl3:ipAddress>
          </nmtl3:interface>
        </nmtl4:endPoint>
      </nmtl4:endPointPair>
    </pinger:subject>

=cut

sub createSubjectL4 {
    my $doc = shift;
    my $ns  = shift;

    my $baseNS   = shift;
    my $protocol = shift;

    my $sourceAddress      = shift;
    my $destinationAddress = shift;

    my $sourceIP      = shift;
    my $destinationIP = shift;

    # subject
    #$logger->debug( "creating subject" );
    my $subj = $doc->createElement( 'subject' );
    $subj->setNamespace( $ns->{$baseNS}, $baseNS );

    #$logger->debug( "creating endpoint pair" );
    my $endPoint = $doc->createElement( 'endPointPair' );
    $endPoint->setNamespace( $ns->getNsByKey( 'nmwgt' ), 'nmwgt' );

    $subj->appendChild( $endPoint );

    my $source = &createEndPointL4( $doc, $ns, { 'ifHostName' => $sourceAddress, 'ipAddress' => $sourceIP }, 'src', $protocol );
    $endPoint->appendChild( $source );

    #$logger->debug( "creating dest" );
    my $dest = &createEndPointL4( $doc, $ns, { 'ifHostName' => $destinationAddress, 'ipAddress' => $destinationIP }, 'dst', $protocol );
    $endPoint->appendChild( $dest );

    return $subj;
}

=head2 createSubjectL3( $doc, $ns, $baseNS, $protocol, $source, $dest )

Creates the subject XML fragment as follows:

=cut

sub createSubjectL3 {
    my $doc = shift;
    my $ns  = shift;

    my $baseNS   = shift;
    my $protocol = shift;

    my $sourceAddress      = shift;
    my $destinationAddress = shift;

    # subject
    #$logger->debug( "creating subject" );
    my $subj = $doc->createElement( 'subject' );
    $subj->setNamespace( $ns->getNsByKey( $baseNS ), $baseNS );

    #$logger->debug( "creating endpoint pair" );
    my $endPoint = $doc->createElement( 'endPointPair' );
    $endPoint->setNamespace( $ns->getNsByKey( 'nmwgt' ), 'nmwgt' );
    $subj->appendChild( $endPoint );

    #$logger->debug( "creating source" );
    my $source = $doc->createElement( 'endPoint' );
    $source->setNamespace( $ns->getNsByKey( 'nmwgt' ), 'nmwgt' );
    $source->setAttribute( 'role',     'src' );
    $source->setAttribute( 'protocol', $protocol );
    $endPoint->appendChild( $source );

    my $sourceNode = $doc->createElement( 'address' );
    $sourceNode->setNamespace( $ns->getNsByKey( 'nmwgt' ), 'nmwgt' );
    $sourceNode->setAttribute( 'value', $sourceAddress );    #TODO:
    $source->appendChild( $sourceNode );

    #$logger->debug( "creating dest" );
    my $dest = $doc->createElement( 'endPoint' );
    $dest->setNamespace( $ns->getNsByKey( 'nmwgt' ), 'nmwgt' );
    $dest->setAttribute( 'role',     'dst' );
    $dest->setAttribute( 'protocol', $protocol );
    $endPoint->appendChild( $dest );

    my $destNode = $doc->createElement( 'address' );
    $destNode->setNamespace( $ns->getNsByKey( 'nmwgt' ), 'nmwgt' );
    $destNode->setAttribute( 'value', $destinationAddress );
    $dest->appendChild( $destNode );

    return $subj;
}

=head2 createParameters($doc, $ns, $baseNS, $hash)

Creates the parameters XML fragment

=cut

sub createParameters {
    my $doc = shift;
    my $ns  = shift;

    my $baseNS = shift;

    my $hash = shift;

    my $param = $doc->createElement( 'parameters' );
    $param->setNamespace( $ns->getNsByKey( $baseNS ), $baseNS );

    while ( my ( $k, $v ) = each %{$hash} ) {
        next if $k =~ /^test/ || $k =~ /^dest/ || $k =~ /^src/;
        my $p = $doc->createElement( 'parameter' );
        $p->setNamespace( $ns->getNsByKey( 'nmwg' ), 'nmwg' );
        $p->setAttribute( 'name', $k );
        my $text = XML::LibXML::Text->new( $v );
        $p->appendChild( $text );
        $param->appendChild( $p );
    }
    return $param;
}

1;

__END__

=head1 SEE ALSO

L<perfSONAR_PS::XML::Namespace>, L<Log::Log4perl>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Base.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Yee-Ting Li <ytl@slac.stanford.edu>

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2007-2009, Internet2 and SLAC National Accelerator Laboratory

All rights reserved.

=cut
