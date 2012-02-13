#!/usr/bin/perl -w

use strict;
use DBI;

use Test::More tests => 4;

BEGIN 
{
  use_ok('perfSONAR_PS::DB::QueryBuilder');
  perfSONAR_PS::DB::QueryBuilder->import(qw(build_select));
}
 my $dbh = undef;
 eval { 
    $dbh =  DBI->connect("DBI:mysql:pingerMA:localhost:", 'www','',  
                              {RaiseError => 0,  PrintError => 0}) or croak $DBI::errstr;
 };
 ok(!$@, " connect db " .  $@);
$@ = undef;

my $sql = 
    build_select
    (
      {dbh     => $dbh,
      select  => 'metaID ',
      tables  => [ 'metaData' ],
      columns => { metaData => [ qw(ip_name_src ip_name_dst metaID) ] },
      query   =>
      [
        metaID  => { 'gt' => [ '1000' ] },    
        ip_name_dst    => { like => [ '%slac%' ] },
     
      ],
      query_is_sql => 1
      }
    );

  ok($sql, " built SQL = $sql ");
  
  eval { 
     my $sth = $dbh->prepare($sql); 
     $sth->execute;
     $sth->finish;
  };
  ok(!$@, " prepare sql  " .  $@);
  
  # XXX: Need more tests here...
 
