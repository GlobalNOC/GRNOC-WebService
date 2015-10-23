#!/usr/bin/perl 
use Test::Simple tests=>8;

use strict;
use GRNOC::WebService;
use JSON::XS;
use Data::Dumper;

my $output;

sub formatter{
    my $data = shift;
    my $fh = shift;
    print $fh JSON::XS::encode_json($data);
}


sub number_echo{
	my $mthod_obj = shift;
	my $params    = shift;

	my %results;

	ok ( defined $params->{'number'},'callback gets expected param');

	$results{'text'} = "input text: ".$params->{'number'}{'value'};

	#--- as number is the only input parameter, lets make sure others dont get past.
	ok( ! defined $params->{'foobar'}, 'callback does not get unexpected param');
	return \%results;
}

my $method = GRNOC::WebService::Method->new(
						name 		=> "number_echo",
						description	=> "descr",
						callback	=> \&number_echo,
						streaming       => 1,
					        output_formatter => \&formatter
						);

ok( defined $method && ref $method eq 'GRNOC::WebService::Method', 'Method->new() works');

$method->add_input_parameter(
				name		=> 'number',
				pattern 	=> '^(\d+)$',
				required	=> 1,
				description	=> "integer input"
			);


#--- printing to stdout seems to screw up the test
open(FH, ">", \$output);


my $svc = GRNOC::WebService::Dispatcher->new(
					test_input 	=> "method=number_echo&number=666&foobar=baz",
					output_handle	=> \*FH,
				);
ok( defined($svc) && ref $svc eq 'GRNOC::WebService::Dispatcher', 'Dispatcher->new() works');

my $res = $svc->register_method($method);

ok( defined($res), 'Dispatcher->regiser_method() works');

my $res2  = $svc->handle_request();

my @input = split(/\n/, $output);

my $struct = JSON::XS::decode_json($input[scalar(@input)-1]);

close(FH);

ok($struct->{'text'} eq "input text: 666" ,"JSON output seems correct");


open(FH, ">", \$output);
$svc = GRNOC::WebService::Dispatcher->new(test_input      => "method=help",
                                          output_handle   => \*FH,
    );
$res2 = $svc->register_method($method);
my $res3  = $svc->handle_request();

ok( defined $res3, 'help works');

$svc = GRNOC::WebService::Dispatcher->new(test_input      => "method=help&method_name=number_echo",
                                          output_handle   => \*FH,
    );

 $res = $svc->register_method($method);
my $res4  = $svc->handle_request();

ok( defined $res4, 'help(method_name) works');
