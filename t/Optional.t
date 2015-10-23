#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 9;
use GRNOC::WebService;
use Data::Dumper;
use JSON::XS;
use FindBin;

my $output;
my $results;

sub optional_method {
    my $method = shift;
    my $params = shift;
    my $state  = shift;

    my $value = "Nothing";

    if ($method->defined_param("optional_parameter")){
	$value = $params->{'optional_parameter'}->{'value'};
    }

    return {results => {"value" => $value}};
}

my $method = GRNOC::WebService::Method->new(
					 name         => 'optional_test',
					 description  => 'tester',
					 expires      => '-1d',
					 output_type  => 'application/json',
					 callback     => \&optional_method,
					 );

$method->add_input_parameter(
			     name         => "optional_parameter",
			     pattern      => '^(\d+)$',
			     required     => 0,
			     multiple     => 0,
			     description  => "An optional parameter to echo back.",
			     );





# actual testing now, first we're testing to see that it works if provided

open(FH, ">", \$output);

my $svc = GRNOC::WebService::Dispatcher->new(
					     test_input      => "method=optional_test&optional_parameter=1337",
					     output_handle   => \*FH
					     );

$svc->register_method($method);

$svc->handle_request();

close(FH);

ok(defined($output),"Results were returned");

#warn Dumper($output);
my @lines = split(/\n/,  $output);

$results = decode_json($lines[scalar(@lines)-1]);

ok(defined($results->{'results'}->{'value'}), "Data looks ok");
is($results->{'results'}->{'value'}, 1337, "Data is good!!");

$output = "";

# now try to test when we have sent the parameter but with not a matching value (should be undefined)
open(FH, ">", \$output);

$svc = GRNOC::WebService::Dispatcher->new(
					  test_input      => "method=optional_test&optional_parameter=",
					  output_handle   => \*FH
					  );

$svc->register_method($method);

$svc->handle_request();

close(FH);


isnt($output, "", "Results were returned");

@lines = split(/\n/, $output);

$results = decode_json($lines[scalar(@lines)-1]);

ok(exists($results->{'results'}->{'value'}), "Data looks ok");
is($results->{'results'}->{'value'}, undef, "Data is good!!");

$output = "";

# finally test what happens when we don't send the parameter at all (should be the same as sending with no value except it is no longer a defined param)
open(FH, ">", \$output);

$svc = GRNOC::WebService::Dispatcher->new(
					  test_input      => "method=optional_test",
					  output_handle   => \*FH
					  );

$svc->register_method($method);

$svc->handle_request();

close(FH);

ok(defined($output),"Results were returned");

@lines = split(/\n/, $output);

$results = decode_json($lines[scalar(@lines)-1]);

ok(exists($results->{'results'}->{'value'}), "Data looks ok");
is($results->{'results'}->{'value'}, "Nothing", "Data is good!!");
