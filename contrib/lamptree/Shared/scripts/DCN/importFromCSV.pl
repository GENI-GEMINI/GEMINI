#!/usr/bin/perl -w

use strict;
use warnings;

use lib "../../lib";

use perfSONAR_PS::Client::DCN;

my $FILE = shift;
die "no CSV file provided\n" unless $FILE;

my $LS = shift;
die "no LS instance provided\n" unless $LS;
my $dcn = new perfSONAR_PS::Client::DCN( { instance => $LS } );

my %csvMap = ();
open my $CSV, '<', $FILE or die "can't open $FILE: $!\n"; 
while ( <$CSV> ) {
    chomp;
    my @csv = split /,/;
    push @ { $csvMap{ $csv[0] } }, $csv[1];
}
close $CSV or warn "can't close $FILE\n";

foreach my $host ( keys %csvMap ) {
    my $ids = $dcn->nameToId( { name => $host } );
    if ( $#{$ids} >= 0 ) {
        my $insert = 1;
        foreach my $c ( @{ $csvMap{ $host } } ) {
            last unless $insert;
            foreach my $c2 ( @{ $ids } ) {
                if ( $c eq $c2 ) {
                    print "SKIP: \"" , $host , " - " , $c , "\" already present.\n";
                    $insert--;
                    last;
                }
            }
        }
    }
    else {
        foreach my $c ( @{ $csvMap{ $host } } ) {
            my $code = $dcn->insert( { name => $host, id => $c } );
            if ( $code == -1 ) {
                print "FAIL: \"" , $host , " - " , $c , "\" insert error.\n";
            }
            else {
                print "PASS: \"" , $host , " - " , $c , "\" inserted.\n";
            }
        }
    }
}



