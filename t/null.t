#!/usr/bin/perl

use strict;
use warnings;

use Test::Simple tests => 2;

use GRNOC::WebService;
use JSON::XS;
use Data::Dumper;

my $output_file;

sub null_test {

  my ( $method, $args, $state ) = @_;

  return {'results' => [{'number_or_null' => $args->{'number_or_null'}{'value'}}]};
}

my $method = GRNOC::WebService::Method->new( name => "null_test",
                                             description  => "null method test",
                                             callback => \&null_test );

$method->add_input_parameter( name => 'number_or_null',
                              pattern => '^(\d+)$',
                              required => 1,
                              description => "number or null",
                              allow_null => 1 );

#--- printing to stdout seems to screw up the test
open( FH, ">", \$output_file);

my $svc = GRNOC::WebService::Dispatcher->new( test_input => 'method=null_test;number_or_null=',
                                              output_handle => \*FH );

$svc->register_method( $method );

$svc->handle_request();

my @input = split(/\n/, $output_file);
my $output = pop( @input );

my $results = JSON::XS::decode_json( $output );
my $result = $results->{'results'}[0];
my @key = keys( %$result );
my @value = values( %$result );

ok( $key[0] eq "number_or_null" );
ok( !defined( $value[0] ) );

close( FH );
