#!/usr/bin/perl
use Test::Simple tests=>1;
use strict;
use GRNOC::WebService;
use JSON::XS;
use Data::Dumper;

my $output;

open(FH, ">", \$output);

sub number_echo{
        my $mthod_obj = shift;
        my $params    = shift;
        $method->set_error('error message');
	return;
}

#--- try out default
my $method2 = GRNOC::WebService::Method->new(
                                                name            => "number_echo2",
                                                description     => "descr",
                                                callback        => \&number_echo
                                                );
$method2->add_input_parameter(
                                name            => 'number',
                                pattern         => '^(\d+)$',
                                required        => 1,
                                description     => "integer input",
                                default         => 666,
                        );

my $svc = GRNOC::WebService::Dispatcher->new(
                                        test_input      => "method=number_echo2",
                                        output_handle   => \*FH,
                                );
$svc->register_method($method2);
$svc->handle_request();

my @input = split(/\n/, $output);
my @content_type = split( /;/, $input[2]);
ok(@content_type[0] eq "Content-Type: application/json" ,"Success: error response returns JSON");

close(FH);
