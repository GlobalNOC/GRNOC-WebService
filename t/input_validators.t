#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 4;
use JSON::XS;
use GRNOC::WebService;
use HTML::Parser;
use Data::Dumper;

our $contains_html = 0;

my $output;

sub echo {

  my ( $methods, $args ) = @_;

  my %results;

  $results{'param'} = $args->{'param'}{'value'};

  return \%results;
}

sub disallow_html {

  my ( $method, $input ) = @_;

  my $parser = HTML::Parser->new();

  # make sure we set this back to zero
  $contains_html = 0;

  # if we make it inside this callback, we discovered an HTML start tag
  sub found_html {

    my $tagname = shift;

    $contains_html = 1;
  }

  $parser->handler( start => \&found_html, 'tagname' );

  $parser->parse( $input );
  $parser->eof();

  return !$contains_html;
}

sub allow_everything {

  my ( $method, $input ) = @_;

  return 1;
}

my $method = GRNOC::WebService::Method->new( name => "echo",
                                             description => "descr",
                                             callback => \&echo );

$method->add_input_parameter( name => 'param',
                              pattern => '^([[:print:]]+)$',
                              required => 1,
                              description => "printable character input" );

open( FH, ">", \$output);

my $svc = GRNOC::WebService::Dispatcher->new( test_input => "method=echo&param=nohtmlhere",
                                              output_handle => \*FH );

$svc->add_default_input_validator( name => 'allow_everything',
                                   description => 'This default input validator will allow any input to validate.',
                                   callback => \&allow_everything );
$svc->add_default_input_validator( name => 'disallow_html',
                                   description => 'This default input validator will invalidate any input that contains HTML.',
                                   callback => \&disallow_html );
$svc->register_method( $method );
$contains_html = 0;
$svc->handle_request();

my @input = split(/\n/,$output);

close( FH );

my $struct = JSON::XS::decode_json( $input[@input - 1] );

is( $struct->{'param'}, "nohtmlhere", "no html found" );

$output = "";
open( FH, ">", \$output);

$svc = GRNOC::WebService::Dispatcher->new( test_input => "method=echo&param=heressomehtml<script>alert('meow)%3B</script>ibetternotvalidate",
                                           output_handle => \*FH );

$svc->add_default_input_validator( name => 'allow_everything',
                                   description => 'This default input validator will allow any input to validate.',
                                   callback => \&allow_everything );
$svc->add_default_input_validator( name => 'disallow_html',
                                   description => 'This default input validator will invalidate any input that contains HTML.',
                                   callback => \&disallow_html );
$svc->register_method( $method );
$contains_html = 0;
$svc->handle_request();

@input = split(/\n/, $output);

close( FH );

$struct = JSON::XS::decode_json( $input[@input - 1] );

is( $struct->{'error'}, 1, "default_input_validator" );

$output = "";
open( FH, ">", \$output);

$svc = GRNOC::WebService::Dispatcher->new( test_input => "method=echo&param=heressomehtml<script>alert('meow)%3B</script>ibetternotvalidate",
                                           output_handle => \*FH );

$method = GRNOC::WebService::Method->new( name => "echo",
                                          description => "descr",
                                          callback => \&echo );

$method->add_input_parameter( name => 'param',
                              pattern => '^([[:print:]]+)$',
                              required => 1,
                              description => "printable character input",
                              ignore_default_input_validators => 1 );

$svc->add_default_input_validator( name => 'allow_everything',
                                   description => 'This default input validator will allow any input to validate.',
                                   callback => \&allow_everything );
$svc->add_default_input_validator( name => 'disallow_html',
                                   description => 'This default input validator will invalidate any input that contains HTML.',
                                   callback => \&disallow_html );
$svc->register_method( $method );
$contains_html = 0;
$svc->handle_request();

@input = split(/\n/, $output);

close( FH );

$struct = JSON::XS::decode_json( $input[@input - 1] );

is( $struct->{'param'}, "heressomehtml<script>alert('meow);</script>ibetternotvalidate", "ignore_default_input_validators" );

$output = "";
open( FH, ">", \$output);

$svc = GRNOC::WebService::Dispatcher->new( test_input => "method=echo&param=heressomehtml<script>alert('meow)%3B</script>ibetternotvalidate",
                                           output_handle => \*FH );

$method = GRNOC::WebService::Method->new( name => "echo",
                                          description => "descr",
                                          callback => \&echo );

$method->add_input_parameter( name => 'param',
                              pattern => '^([[:print:]]+)$',
                              required => 1,
                              description => "printable character input" );

$svc->add_default_input_validator( name => 'allow_everything',
                                   description => 'This default input validator will allow any input to validate.',
                                   callback => \&allow_everything );

$method->add_input_validator( name => 'allow_everything',
                              description => 'This input validator will allow any input to validate.',
                              callback => \&allow_everything,
                              input_parameter => 'param' );

$method->add_input_validator( name => 'disallow_html',
                              description => 'This input validator will disallow any HTML input.',
                              callback => \&disallow_html,
                              input_parameter => 'param' );

$svc->register_method( $method );
$contains_html = 0;
$svc->handle_request();

@input = split(/\n/, $output);

close( FH );

$struct = JSON::XS::decode_json( $input[@input - 1] );

is( $struct->{'error'}, 1, "input_validator" );
