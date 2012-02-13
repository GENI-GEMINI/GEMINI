#!/usr/bin/perl

# $Id: $

use strict;
use warnings;

use PPI;
use PPI::Dumper;
use PPI::Token::Pod;
use Getopt::Long;
use File::Spec; 
use Log::Log4perl qw(:levels :easy);
use Pod::Usage;
use Cwd;
use File::Find;
use Switch;


=head1 NAME

make_pod.pl -  create  POD in-situ where its needed

=head1  DESCRIPTION

inserts POD for any perl package by parsing perl files,
extracting existing POD and
adding mising POD for subs, constants, fields etc...
Based on L<PPI>. It edits document in-situ but stores updated
with C<.podfied> extension. It does not override  original files !
It works with more or less modern OO perl code. It will work with old and ugly
code but with less usefulness.

=head1  SYNOPSIS

make_pod.pl  [--debug]  [--help] [--path=PATH]  [--file=FILE]

=head1 OPTIONS

=head2   C<--debug>

Set debugging mode, more logging.

=head2   C<--path=PATH>

A directory  name PATH  to open for PODifying. Defaults to cwd.

=head2 C<--file=FILE>

A filename  FILE  to open for PODifying. Defaults to cwd.

=head1 EXAMPLES

  ./make_pod.pl --file=SomeModuleWithoutDocs.pm

  will add all necessary POD

=cut

our $options = {};
 
GetOptions( $options, qw(path|p=s  help|h debug|d   file|f=s) ) or pod2usage(2);
pod2usage(1) if ($options->{help});
$options->{debug}?
    Log::Log4perl->easy_init($DEBUG):
        Log::Log4perl->easy_init($INFO);
our $LOGGER= get_logger('make_pod');

my ($directory, $file);
if($options->{path}) {
    $LOGGER->logdie("Option --path=$options->{path} was supplied with wrong directory path")
        unless -d $options->{path};
    $directory =  File::Spec->canonpath( $options->{path} );
} 
           
if($options->{file}) {
    $LOGGER->logdie("Option --file=$options->{file} was supplied with malformed filename")
        unless -f $options->{file};
    $file = $options->{file};
}
# defaults to cwd
$directory =  getcwd() unless $directory;
if($file) {
    make_pods($file);
}
else {
    find({  wanted =>  sub { /\/?\w+\.pm$/ && make_pods(  $File::Find::name ) }, 
            no_chdir => 1 },  
            $directory);
}


#
#    PODfy in-situ specific file
#
sub make_pods {
    my($file) = @_;
    $LOGGER->debug("making POD for a file: $file ...");
    my $doc = PPI::Document->new($file);
    $PPI::Document::errstr && $LOGGER->logdie($PPI::Document::errstr);
    my $pkg = $doc->find_first('PPI::Statement::Package');
    my $packagename = $pkg->namespace;
    my $inherited = '';
    my @includes;
    foreach my $include  (@{$doc->find('PPI::Statement::Include')}) {
        my $module = $include->module;
        if($module  =~ /^base$/) {
            $inherited = ' this module is extending module L<' . $include->find_first('PPI::Token::Quote') . '> ';
        }
        elsif($module !~ m/^(strict|warnings)$/) {
            push @includes,   "L<$module>";
        }
    }
    my $pods = $doc->find('PPI::Token::Pod');
    my @pods_order = ('NAME', 'DESCRIPTION', 'SYNOPSIS',  'SEE ALSO', 'METHODS');
    
    my %pod_missing;
    my $insert_after = $pkg;
    if($pods && @{$pods}) {
        foreach my $item (@pods_order) {
            my $found;
            foreach my $pod (@{$pods}) {   
                if($pod->content =~ /\b$item\b/ms) {
                    $found++;
                    $insert_after = $pod;
                    last;
                } 
            }
            $pod_missing{$item} =  $insert_after unless  $found;
        }
    } else {
         map { $pod_missing{$_} = $pkg } @pods_order; 
    }
     
    #  parsing every sub to get more info into SYNOPSIS and create pod for the sub
    #
    my $subs =  $doc->find('PPI::Statement::Sub');
    my $subnames_str = '';
    foreach my $node ( @{$subs} ) {  
        my $found;
	my $node2 = $node->previous_sibling();
	while(!$node2 || $node2->content =~ /^\s+$/) {
           $node2 = $node2->previous_sibling();
           $LOGGER->debug(" PREVIOUS : ", $node2->content);
        }
        my $proto =   $node->prototype;
        my $subname = $node->name; 
        ### skipping private functions
        my $method = ($subname =~ /^\_/)?next:'  function call';
        $subnames_str .= "    #   function \n    $subname($proto); #    add comment here \n";
        my $block =   $node->block;
                
        my $sub_pod  =  "\n=head2  C<${subname}$proto> -  $method\n\nC<Arguments:>\n";
        my %returns;
        my @block_snodes = $block->schildren;
        ##  geting arguments list
	foreach my  $var ( @block_snodes ) { 
            $LOGGER->debug(" Var : " . $var->content);
            if($var->isa('PPI::Statement::Variable') ) {
                my $arr_ref_magic =   $var->find('PPI::Token::Magic');
                if($arr_ref_magic && $arr_ref_magic->[0]  eq '@_') {
                    my $list =  $var->find('PPI::Structure::List');
                    my @arguments =  parse_args(@{$list->[0]->find('PPI::Token::Symbol')});
                    $sub_pod .=  '    ' . (join ' ',   @arguments) .  "\n";
                    
                } 
                elsif($var->type eq 'my' and $var->content =~  /shift/xms) {
                    $sub_pod .= '    ' . join ' ', parse_args(@{$var->find('PPI::Token::Symbol')}); 
                } 
            }
         }
         my $order=0;
         my @block_nodes = $block->children;
         ##  geting all possible returns. NOTE: may not work 100%
         foreach my  $var ( @block_nodes ) { 
            if ($var->isa('PPI::Statement::Break') && $var->content =~ /return/xims)  {
                $LOGGER->debug(" Break dump : ", sub{my $a = PPI::Dumper->new($var); $a->string}); 
     	       
	        my ($type, $what, @rest) =   $var->schildren();
                my $rest_str = (join ' ', grep {!/;/} @rest);
                $rest_str = '' 
                    if $what  =~ /\b(if|unless)\b/xims || $rest_str =~ /\b(if|unless)\b/xims;
                $what = 'undef' 
                    if !$what || $what eq 'undef' ||  !$what->isa('PPI::Token::Symbol');
                $rest_str =~ s/\s//g;
                $returns{$what . ' ' . $rest_str} = $order++;
            }       
        }          
        $returns{'last statement'} = $order++ 
            if !%returns || !$block_snodes[-1]->isa('PPI::Statement::Break'); 
         
        $sub_pod .=  "\n \nC<Possible Returns:>\n    " .  
                     (join "\n    ",  (map {" $_ - add comments here " } 
                                         sort {$returns{$a} <=> $returns{$b}}   
                                         keys %returns
                                        )
                     ) .
                     "\n";
        $sub_pod .=  "\n=cut\n\n";
        $node->insert_before(PPI::Token::Pod->new($sub_pod)) unless($node2->isa('PPI::Token::Pod') && $node2->content =~ /^\=head2/);   
    }
    foreach my  $item (reverse @pods_order) {
        next unless $pod_missing{$item};
        switch($item) {
            case  'NAME'         {set_pod($item, {node => $pod_missing{$item}, extra =>  "$packagename -   perfSONAR-PS API module"})}
            case  'DESCRIPTION'  {set_pod($item, {node => $pod_missing{$item}, extra =>  "... $inherited ..."})}
            case  'SYNOPSIS'     {set_pod($item, {node => $pod_missing{$item}, extra =>  "    use $packagename;\n$subnames_str"})}                           
            case  'METHODS'      {set_pod($item, {node => $pod_missing{$item}, extra => ''})}
            case  'SEE ALSO'     {set_pod($item, {node => $pod_missing{$item}, extra => "See also next modules for more details:\n".
                                                                                            (join ', ',  @includes) })}     
        }
    }
    $doc->save($file . '.podfied');
}

#
#   set_pod - inserts pod for major sections
#    accepts name of the section and hashref to
#      node => PPI::Element - node to insert this after
#      extra => string to print inside of that section 
#

sub set_pod {
    my($head1, $insert_href) = @_;
    $LOGGER->logdie(" first parameter is scalar and second one is hashref with 'node' => PPI::Element and 'extra' => scalar ")
        unless ( ref $insert_href eq 'HASH' && $insert_href->{node}->isa('PPI::Element'));
    $insert_href->{node}->insert_after(PPI::Token::Pod->new("\n\n=head1  $head1\n\n$insert_href->{extra}\n\n=cut\n\n"));
}

#
#   parse arguments, filter out $self and replace $r
#

sub parse_args {
    return    grep {! m/\$self/xims} @_;
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

$Id$

=head1 AUTHOR

Maxim Grigoriev, maxim_at_fnal_dot_gov

=head1 LICENSE

You should have received a copy of  the Fermitools license
along with this software. If not, see
<http://fermitools.fnal.gov/about/terms.html>

=head1 COPYRIGHT

Copyright (c)  2009,   Fermi Research Alliance (FRA)

All rights reserved.

=cut
