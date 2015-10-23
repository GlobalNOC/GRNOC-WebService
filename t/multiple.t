#!/usr/bin/perl
use Test::Simple tests => 2;
use strict;
use GRNOC::WebService;
use JSON::XS;
use Data::Dumper;

my $output;

sub input_count{
        my $mthod_obj = shift;
        my $params    = shift;

        my %results;

	my $count  =   scalar @{$params->{'number'}{'value'}};
	#warn Dumper($params);

	$results{'text'} = "input count: $count";

        return \%results;

}



#--- try out default
my $method2 = GRNOC::WebService::Method->new(
                                                name            => "input_count",
                                                description     => "descr",
                                                callback        => \&input_count
                                                );
$method2->add_input_parameter(
                                name            => 'number',
                                pattern         => '^(\d+)$',
                                required        => 1,
                                description     => "integer input",
                                multiple        => 1,
                        );


open(FH, ">", \$output);

my $svc = GRNOC::WebService::Dispatcher->new(
                                        test_input      => "method=input_count;number=1;number=2;number=3",
                                        output_handle   => \*FH,
                                );
$svc->register_method($method2);
$svc->handle_request();

my @input = split(/\n/, $output);


my $struct = JSON::XS::decode_json($input[scalar(@input)-1]);

ok($struct->{'text'} eq "input count: 3" ,"multiples work");

$output = "";

$svc->{'test_input'} = "method=input_count;number=4;number=5;number=6;number=7;number=8";
$svc->handle_request();

@input = split(/\n/, $output);

$struct = JSON::XS::decode_json($input[scalar(@input)-1]);

ok($struct->{'text'} eq "input count: 5", "multiples under mod_perl should work");
close(FH);
