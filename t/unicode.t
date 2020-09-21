#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 2;
use GRNOC::WebService;
use JSON::XS;
use URI::Escape qw(uri_escape_utf8) ;
use Data::Dumper;

my $output;

open(FH, ">", \$output);

sub string_echo {

    my $mthod_obj = shift;
    my $params    = shift;

    my %results;

    $results{'text'} = "input text: " . $params->{'string'}{'value'};

    return \%results;
}

#--- try out default
my $method = GRNOC::WebService::Method->new( name => "string_echo",
					     description => "descr",
					     callback => \&string_echo );

$method->add_input_parameter( name => 'string',
			      pattern => '^([[:print:][:space:]]+)$',
			      #pattern => '^(.*)$',
			      required => 1,
			      description => "string input" );

my $svc = GRNOC::WebService::Dispatcher->new( test_input => "method=string_echo;string=" . uri_escape_utf8( "\N{U+2014}" ),
					      output_handle => \*FH );

$svc->register_method( $method );
$svc->handle_request();

my @input = split(/\n/, $output);

my $length;

foreach my $line (@input){
    if($line =~ /Content-length: (\d+)/){
	$length = $1;
    }
}

my $content_length = length ($input[ scalar(@input) - 1 ]);

ok($content_length == $length, "Length matches content length");

my $struct = JSON::XS::decode_json( $input[ scalar(@input) - 1 ] );

is( $struct->{'text'}, "input text: \N{U+2014}", "unicode works" );

close(FH);
