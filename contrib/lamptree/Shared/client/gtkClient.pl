#!/usr/bin/perl -w

use strict;
use warnings;

=head1 NAME

gtkClient.pl - GTK2 client for perfSONAR

=head1 DESCRIPTION

Basic Gtk2 based client to send and recieve XML messages to different perfSONAR
services.  This client uses Gtk2::SourceView for XML syntax coloring.  In order
to keep compatability with command line version this client takes the same
arguments as the command line version.

But it had two differences:

1- Running this client without any arguments will not cause any error and the
   graphical interface will run by default.

2- If same arguments supplied as command line version no graphical interface
   will run unless the option '--gtk' is supplied

=cut

use Getopt::Long;
use Log::Log4perl qw(:easy);
use File::Basename;
use Carp;
use English qw( -no_match_vars );
use XML::Twig;
use Glib qw/TRUE FALSE/;
use Gtk2 '-init';
use Gtk2::SourceView;
use Gtk2::SimpleMenu;

my $dirname;
my $libdir;

# we need to figure out what the library is at compile time so that "use lib"
# doesn't fail. To do this, we enclose the calculation of it in a BEGIN block.
BEGIN {
    $dirname = dirname( $PROGRAM_NAME );
    $libdir  = $dirname . "/../lib";
}

use lib "$libdir";

use perfSONAR_PS::Transport;
use perfSONAR_PS::Common qw( readXML );
use perfSONAR_PS::Utils::NetLogger;
use perfSONAR_PS::Utils::ParameterValidation;

our $DEBUGFLAG;
our %opts = ();
our $help_needed;

#Gtk client uses the same arguments as command line client, but here its all
#  optional If the option --gtk is not used the client will behave exactlly as
#   the command line version

my $ok = GetOptions(
    'debug'      => \$DEBUGFLAG,
    'server=s'   => \$opts{HOST},
    'port=s'     => \$opts{PORT},
    'endpoint=s' => \$opts{ENDPOINT},
    'filter=s'   => \$opts{FILTER},
    'gtk'        => \$opts{GTK},
    'help'       => \$help_needed
);

if ( $help_needed ) {
    print_help();
    exit( 1 );
}

our $level = $INFO;
$level = $DEBUG if $DEBUGFLAG;

Log::Log4perl->easy_init( $level );
my $logger = get_logger( "perfSONAR_PS" );

my $host     = q{};
my $port     = q{};
my $endpoint = q{};
my $filter   = '/';
my $file     = q{};
my $xml      = q{};
my $useGtk   = 0;
my $window;

unless ( scalar @ARGV == 0 ) {
    if ( scalar @ARGV == 2 ) {
        ( $host, $port, $endpoint ) = &perfSONAR_PS::Transport::splitURI( $ARGV[0] );

        unless ( $host and $port and $endpoint ) {
            print_help();
            croak "Argument 1 must be a URI if more than one parameter used.\n";
        }

        $file = $ARGV[1];
    }
    elsif ( scalar @ARGV == 1 ) {
        $file = $ARGV[0];
    }
    else {
        print_help();
        croak "Invalid number of parameters: must be 1 for just a file, or 2 for a uri and a file";
    }

    croak "File $file does not exist" unless -f $file;
    $xml = readXML( $file );
}
else {
    $opts{GTK} = 1;
}

if ( defined $opts{HOST} ) {
    $host = $opts{HOST};
}
if ( defined $opts{PORT} ) {
    $port = $opts{PORT};
}
if ( defined $opts{ENDPOINT} ) {
    $endpoint = $opts{ENDPOINT};
}
if ( defined $opts{FILTER} ) {
    $filter = $opts{FILTER};
}
if ( defined $opts{GTK} ) {
    $useGtk = 1;
}

if ( $useGtk == 1 ) {

    #Initialize the main window
    $window = Gtk2::Window->new( 'toplevel' );
    $window->set_title( "perfSONAR Client" );
    $window->signal_connect( delete_event => \&delete_event );
    $window->set_border_width( 10 );
    $window->set_position( 'center_always' );
    $window->add( &prepare_gui() );
    $window->show_all;
    Gtk2->main;
}
else {
    print formatXML( send_message( $host, $port, $endpoint, readXML( $file ) ) ) . "\n";
}

=head2 function send_message( $host, $port, $endpoint, $message)

Send XML message to the destination perfSONAR service and return the XML output.

=cut

sub send_message {
    my ( @args ) = @_;
    ( $host, $port, $endpoint, $xml ) = validateParams( @args, {} );

    unless ( $host and $port and $endpoint ) {
        return "You must specify the host, port and endpoint";
    }

    # start a transport agent
    my $sender = perfSONAR_PS::Transport->new( $host, $port, $endpoint );

    # Make a SOAP envelope, use the XML file as the body.
    my $envelope = &perfSONAR_PS::Common::makeEnvelope( $xml );
    my $error;

    # Send/receive to the server, store the response for later processing
    my $msg = perfSONAR_PS::Utils::NetLogger::format( "org.perfSONAR.client.sendReceive.start", { host => $host, port => $port, endpoint => $endpoint, } );
    $logger->debug( $msg );

    my $responseContent = $sender->sendReceive( $envelope, q{}, \$error );

    $msg = perfSONAR_PS::Utils::NetLogger::format( "org.perfSONAR.client.sendReceive.end", );
    $logger->debug( $msg );

    return "Error sending request to service: $error" if $error;

    return dumpXML( { response => $responseContent, find => $filter } );
}

=head2 function dumpXML({response, find})

dump the content, using the xpath statement if necessary

=cut

sub dumpXML {
    my ( @args ) = @_;
    my $parameters = validateParams( @args, { response => 1, find => 1 } );
    my $xp         = q{};
    my $str        = q{};

    if ( ( UNIVERSAL::can( $parameters->{response}, "isa" ) ? 1 : 0 == 1 ) and ( $xml->isa( 'XML::LibXML' ) ) ) {
        $xp = $parameters->{response};
    }
    else {
        my $parser = XML::LibXML->new();
        $xp = $parser->parse_string( $parameters->{response} );
    }

    my @res = $xp->findnodes( $parameters->{find} );
    foreach my $n ( @res ) {
        $str = $str . $n->toString() . "\n";
    }
    return $str;
}

=head2 function formatXML($sXML)

Just make XML prettier and easier to read

=cut

sub formatXML {
    my ( $sXML ) = @_;
    my $tabs = 4;
    if ( $sXML eq q{} ) {
        return q{};
    }
    my $params        = [qw(none nsgmls nice indented record record_c)];
    my $sPrettyFormat = $params->[3] || 'none';
    my $twig          = XML::Twig->new;
    $twig->set_indent( " " x $tabs );

    my $ref = eval { $twig->parse( $sXML ); };

    if ( $@ ) {
        return $sXML;
    }
    else {
        $twig->set_pretty_print( $sPrettyFormat );
        $sXML = $twig->sprint;
        return $sXML;
    }
}

=head2 prepare_gui

Prepare GUI compenents

=cut

sub prepare_gui {

    #Input entrys for access point
    my $box = Gtk2::HBox->new( TRUE, 7 );
    $box->set_homogeneous( FALSE );

    my $host_lbl = Gtk2::Label->new( "Host:" );
    $box->pack_start( $host_lbl, FALSE, FALSE, 0 );

    my $host_entry = Gtk2::Entry->new;
    $box->pack_start( $host_entry, FALSE, FALSE, 0 );

    my $port_lbl = Gtk2::Label->new( "Port:" );
    $box->pack_start( $port_lbl, FALSE, FALSE, 0 );

    my $port_entry = Gtk2::Entry->new;
    $box->pack_start( $port_entry, FALSE, FALSE, 0 );

    my $endpoint_lbl = Gtk2::Label->new( "Endpoint:" );
    $box->pack_start( $endpoint_lbl, FALSE, FALSE, 0 );

    my $endpoint_entry = Gtk2::Entry->new;
    $box->pack_start( $endpoint_entry, TRUE, TRUE, 0 );

    my $send = Gtk2::Button->new( "Send" );
    $box->pack_start( $send, FALSE, FALSE, 0 );

    #Vertical pane for input and output boxes
    my $pane = Gtk2::VPaned->new;

    #Setting up Gtk2::SourceView for input
    my ( $input_sw, $input_view ) = prepare_source_view();
    $pane->add1( $input_sw );

    #Setting up Gtk2::SourceView for output
    my ( $output_sw, $output_view ) = prepare_source_view();
    $pane->add2( $output_sw );

    $send->signal_connect(
        clicked => sub {
            $xml = send_message( $host_entry->get_text, $port_entry->get_text, $endpoint_entry->get_text, $input_view->get_buffer()->get_text( $input_view->get_buffer()->get_bounds(), TRUE ) );
            $output_view->get_buffer()->set_text( formatXML( $xml ) );
        }
    );

    #Init menu bar
    my $menu_tree = [
        _File => {
            item_type => '<Branch>',
            children  => [
                _New => {
                    item_type => '<StockItem>',
                    callback  => sub {
                        ( $host, $port, $endpoint, $xml ) = ( q{}, q{}, q{}, q{} );

                        $host_entry->set_text( $host );
                        $port_entry->set_text( $port );
                        $endpoint_entry->set_text( $endpoint );
                        $input_view->get_buffer()->set_text( $xml );
                        $output_view->get_buffer()->set_text( q{} );
                    },
                    accelerator => '<ctrl>N',
                    extra_data  => 'gtk-new',
                },
                '_Open XML' => {
                    item_type => '<StockItem>',
                    callback  => sub {
                        my $chooser = Gtk2::FileChooserDialog->new(
                            "Open XML document", $window, "open",
                            'gtk-cancel' => 'cancel',
                            'gtk-open'   => 'ok'
                        );
                        $chooser->set_default_response( 'cancel' );

                        if ( 'ok' eq $chooser->run() ) {
                            $xml = readXML( $chooser->get_filename );
                            $port_entry->set_text( $port );
                            $endpoint_entry->set_text( $endpoint );
                            $input_view->get_buffer()->set_text( $xml );
                            $output_view->get_buffer()->set_text( q{} );
                        }

                        $chooser->destroy;
                    },
                    accelerator => '<ctrl>S',
                    extra_data  => 'gtk-save',
                },
                _Quit => {
                    item_type   => '<StockItem>',
                    callback    => \&delete_event,
                    accelerator => '<ctrl>Q',
                    extra_data  => 'gtk-quit',
                }
            ]
        },
        _View => {
            item_type => '<Branch>',
            children  => [
                '_Format XML' => {
                    item_type => '<StockItem>',
                    callback  => sub {
                        $input_view->get_buffer()->set_text( formatXML( $input_view->get_buffer()->get_text( $input_view->get_buffer()->get_bounds(),    TRUE ) ) );
                        $output_view->get_buffer()->set_text( formatXML( $output_view->get_buffer()->get_text( $output_view->get_buffer()->get_bounds(), TRUE ) ) );
                    },
                    accelerator => '<ctrl>F',
                    extra_data  => q{},
                }
            ],
        }
    ];

    my $menu = Gtk2::SimpleMenu->new( menu_tree => $menu_tree );

    #Init main table
    my $table_main = Gtk2::Table->new( 4, 3, FALSE );
    $table_main->attach( $menu->{widget}, 0, 1, 0, 1, [ 'fill', 'shrink', 'expand' ], [], 2, 2 );
    $table_main->attach( $box, 0, 1, 1, 2, [ 'fill', 'shrink', 'expand' ], [], 2, 2 );
    $table_main->attach( $pane, 0, 1, 2, 3, [ 'fill', 'shrink', 'expand' ], [ 'fill', 'shrink', 'expand' ], 5, 5 );

    #Init the inputs from command line arguments (if any supplied)
    $host_entry->set_text( $host );
    $port_entry->set_text( $port );
    $endpoint_entry->set_text( $endpoint );
    $input_view->get_buffer()->set_text( $xml );

    return $table_main;
}

=head2 function prepare_source_view
    
Create Gtk2::SourceView and setting it parameters to format XML.
Return (scroll window, view)

=cut

sub prepare_source_view {
    my $manager   = Gtk2::SourceView::LanguagesManager->new;
    my $buffer    = Gtk2::SourceView::Buffer->new( undef );
    my $lang      = $manager->get_language_from_mime_type( "text/xml" );
    my $view      = Gtk2::SourceView::View->new_with_buffer( $buffer );
    my $font_desc = Gtk2::Pango::FontDescription->from_string( "monospace 10" );
    my $sw        = Gtk2::ScrolledWindow->new( undef, undef );

    $buffer->{'languages_manager'} = $manager;
    $buffer->set( 'highlight', TRUE );
    $buffer->set_language( $lang );

    if ( $font_desc ) {
        $view->modify_font( $font_desc );
    }

    $sw->set_shadow_type( 'etched-out' );
    $sw->set_policy( 'automatic', 'automatic' );
    $sw->set_size_request( 300, 300 );
    $sw->set_border_width( 5 );
    $sw->add( $view );

    return ( $sw, $view );
}

=head2 function delete_event()

Exit the program on window close signal

=cut

sub delete_event {
    Gtk2->main_quit;
    return FALSE;
}

=head2 help()

Print a help message

=cut

sub print_help {
    print "$PROGRAM_NAME: sends an xml file to the server on specified port.\n";
    print "    ./client.pl [--gtk] [--server=xxx.yyy.zzz --port=n --endpoint=ENDPOINT] [URI] FILENAME\n";
    return;
}

1;

__END__

=head1 SEE ALSO

L<use Getopt::Long>, L<Log::Log4perl>, L<File::Basename>, L<Carp>, L<English>,
L<XML::Twig>, L<Glib>, L<Gtk2>, L<Gtk2::SourceView>, L<Gtk2::SimpleMenu>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/psps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: gtkClient.pl 3914 2010-02-19 13:51:54Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu
Yee-Ting Li <ytl@slac.stanford.edu>
Ahmed El-Hassany <a.hassany@gmail.com> 

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2010, Internet2 and the University of Delaware

All rights reserved.

=cut
