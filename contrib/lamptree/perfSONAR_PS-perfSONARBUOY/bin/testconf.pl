#!/usr/bin/perl -w
#
#      $Id: testconf.pl 3795 2009-12-11 07:02:22Z boote $
#
#########################################################################
#									#
#			   Copyright (C)  2002				#
#	     			Internet2				#
#			   All Rights Reserved				#
#									#
#########################################################################
#
#	File:		testconf.pl
#
#	Author:		Jeff Boote
#			Internet2
#
#	Date:		Wed Sep 25 09:18:23  2002
#
#	Description:	
#
#	Usage:
#
#	Environment:
#
#	Files:
#
#	Options:
use strict;
use Getopt::Std;
use FindBin;
# BEGIN FIXMORE HACK - DO NOT EDIT
# %amidefaults is initialized by fixmore MakeMaker hack
my %amidefaults;
BEGIN{
    %amidefaults = (
        CONFDIR	=> "$FindBin::Bin/../etc",
        LIBDIR	=> "$FindBin::Bin/../lib",
    );
}
# END FIXMORE HACK - DO NOT EDIT

# use amidefaults to find other modules $env('PERL5LIB') still works...
use lib $amidefaults{'LIBDIR'};
use OWP;
use OWP::Helper;
use OWP::MeasSet;

my %options = (
	CONFDIR	    =>	"c:",
	LOCALNODES  =>	"n:",
);

my %optnames;
foreach (keys %options){
    my $key = substr($options{$_},0,1);
    $optnames{$key}=$_;
}
my $options = join '', values %options;
my %setopts;
getopts($options,\%setopts);
foreach (keys %optnames){
	$amidefaults{$optnames{$_}} = $setopts{$_} if defined($setopts{$_});
}

my $conf = new OWP::Conf(%amidefaults);

my($key);

print $conf->dump;

#
# Find all 'groups'
#
my @meshes = $conf->get_list(LIST=>'GROUP',ATTR=>'GROUPTYPE',VALUE=>'MESH');
my @stars = $conf->get_list(LIST=>'GROUP',ATTR=>'GROUPTYPE',VALUE=>'STAR');
my @alltests = $conf->get_val(ATTR=>'TESTSPECLIST');
my @allnodes = $conf->get_val(ATTR=>'NODELIST');

my @owamptests = $conf->get_list(
    LIST=>'TESTSPEC',
    ATTR=>'TOOL',
    VALUE=>'powstream');

my @bwctltests = $conf->get_list(
    LIST=>'TESTSPEC',
    ATTR=>'TOOL',
    VALUE=>'bwctl/iperf');

my (@owampmeshes,@bwctlmeshes,@owampstars,@bwctlstars);
my ($ttest,$tgroup,%tf);

foreach $ttest (@owamptests){
    foreach $tgroup (@meshes){
        undef %tf;
        $tf{'TESTSPEC'} = $ttest;
        $tf{'GROUP'} = $tgroup;
        push @owampmeshes, $conf->get_list(
            LIST=>'MEASUREMENTSET',
            FILTER=>\%tf);
    }
}

print "owampmeshes: ".join(' ',@owampmeshes)."\n";

my (@owampmsets,@bwctlmsets);

foreach $ttest (@owamptests){
    push @owampmsets, $conf->get_list(
        LIST=>'MEASUREMENTSET',
        ATTR=>'TESTSPEC',
        VALUE=>$ttest);
}

foreach $ttest (@bwctltests){
    push @bwctlmsets, $conf->get_list(
        LIST=>'MEASUREMENTSET',
        ATTR=>'TESTSPEC',
        VALUE=>$ttest);
}

print "meshes: ".join(' ',@meshes)."\n";
print "stars: ".join(' ',@stars)."\n";
print "bwctlmsets: ".join(' ',@bwctlmsets)."\n";
print "owampmsets: ".join(' ',@owampmsets)."\n";

my @localnodes = $conf->get_val( ATTR => 'LOCALNODES' );
if ( !defined( $localnodes[0] ) ) {
    my $me = $conf->get_val( ATTR => 'NODE' );
    @localnodes = ($me);
}

if ( @localnodes < 1) {
    warn "Set the -n flag with a nodename to see what tests would be performed from that node";
    exit 0;
}

#my ($mesh,$mset,@owmeshes,@bwmeshes,@owstars,@bwstars);
#foreach $mesh (@meshes){
#    foreach $mset (@owampmsets){
#        $group = $conf->get_val(MEASUREMENTSET=>$mset,ATTR=>GROUP);
#        next if($group ne $mesh);
#
# setup loop - build the directories needed for holding temporary data.
# - data is held in datadir/$msetname/$recv/$send
#
my ( $mset, $recv, $send );
my @dirlist;
foreach $mset (@bwctlmsets, @owampmsets) {
    my $me;

    my $msetdesc = new OWP::MeasSet(
        CONF            => $conf,
        MEASUREMENTSET  => $mset);

    # skip msets that are invoked centrally
    # XXX: Need to implement this in powcollector still!
    next if ( $msetdesc->{'CENTRALLY_INVOLKED'});

    foreach $me (@localnodes) {

        if(defined($conf->get_val(NODE=>$me,ATTR=>'NOAGENT'))){
            die "configuration specifies NODE=$me should not run an agent";
        }

        # determine path for recv-relative tests started from this host
        foreach $recv ( keys %{ $msetdesc->{'RECEIVERS'} }){

            #
            # If recv is not the localnode currently doing, skip.
            #
            next if ( $me ne $recv );

            foreach $send ( @{ $msetdesc->{'RECEIVERS'}->{$recv}} ) {

                # bwctl always excludes self tests, but powstream doesn't.
                # XXX: Need to add a 'tool' definition somewhere where
                # defaults like 'tool-can-do-self-tests' can be
                # specified
                # next if ( $recv eq $send );

                # XXX: testconf currently LIES and says it does localhost tests
                # for bwctl since this doesn't differentiate bwctl/owamp
                # NEED TO FIX

                push @dirlist, "$mset/$recv/$send";
            }
        }

        # determine path for send-relative tests started from this host
        # (If the remote host does not run powmaster.)
        foreach $send ( keys %{ $msetdesc->{'SENDERS'} }){

            #
            #
            # If send is not the localnode currently doing, skip.
            #
            next if ( $me ne $send );

            foreach $recv ( @{ $msetdesc->{'SENDERS'}->{$send}} ) {

                # bwctl always excludes self tests, but powstream doesn't.
                # XXX: tool def for self-tests again... see above.
                #next if ( $recv eq $send );

                # run 'sender' side tests for noagent receivers
                next if (!defined($conf->get_val(NODE=>$recv,ATTR=>'NOAGENT')));

                push @dirlist, "$mset/$recv/$send";
            }
        }
    }
}
die "No tests to be run by this node (@localnodes)." if ( !scalar @dirlist );

foreach ( @dirlist ){
    print "$_\n";
}

exit 0;

1;
