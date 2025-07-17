use Test::More tests => 35;

use strict;
use GRNOC::WebService;
use GRNOC::WebService::Regex;
use JSON::XS;
use Data::Dumper;

my $output;

sub number_echo{
  my $mthod_obj = shift;
  my $params    = shift;

  my %results;

  ok ( defined $params->{'number'},'callback gets expected param');

  $results{'text'} = "input text: ".$params->{'number'}{'value'};
  $results{'text'} .= " date: $params->{'date'}{'value'}" if defined($params->{'date'}{'value'});
  $results{'text'} .= " comment: $params->{'comment'}{'value'}" if ( defined( $params->{'comment'}{'value'} ) );

  #--- as number is the only input parameter, lets make sure others dont get past.
  ok( ! defined $params->{'foobar'}, 'callback does not get unexpected param');
  return \%results;
}


my $method = GRNOC::WebService::Method->new(
                                            name    => "number_echo",
                                            description => "descr",
                                            callback  => \&number_echo
                                           );

ok( defined $method && ref $method eq 'GRNOC::WebService::Method', 'Method->new() works');

$method->add_input_parameter(
                             name   => 'number',
                             pattern  => '^(\d+)$',
                             required => 1,
                             description  => "integer input",
                             min_length => 2,
                             max_length => 12
                            );

$method->add_input_parameter(
                             name   => 'hidden',
                             pattern  => '^(\d+)$',
                             required => 0,
                             is_hidden => 1,
                             description  => "hidden input",
                            );

$method->add_input_parameter( name        => 'date',
                              pattern     => '^(\d\d\d\d-\d\d-\d\d)$',
                              required    => 0,
                              description => "Date in YYYY-MM-DD format." );


$method->add_input_parameter( name => 'comment',
                              pattern => $TEXT,
                              required => 0,
                              description => 'A comment that accepts newline characters.' );

#--- printing to stdout seems to screw up the test
open(FH, ">", \$output);


my $svc = GRNOC::WebService::Dispatcher->new(
                                             test_input   => "method=number_echo&number=666&foobar=baz",
                                             output_handle  => \*FH,
                                            );
ok( defined($svc) && ref $svc eq 'GRNOC::WebService::Dispatcher', 'Dispatcher->new() works');

my $res = $svc->register_method($method);

ok( defined($res), 'Dispatcher->regiser_method() works');

my $res2  = $svc->handle_request();

my @input = split(/\n/, $output);

my $struct = JSON::XS::decode_json($input[scalar(@input)-1]);


ok($struct->{'text'} eq "input text: 666" ,"JSON output seems correct");

close(FH);

open(FH, ">", \$output);
$svc = GRNOC::WebService::Dispatcher->new(
                                          test_input      => "method=help",
                                          output_handle   => \*FH,
                                         );
$res2 = $svc->register_method($method);
my $res3  = $svc->handle_request();


ok( defined $res3, 'help works');


$svc = GRNOC::WebService::Dispatcher->new(
                                          test_input      => "method=help&method_name=number_echo",
                                          output_handle   => \*FH,
                                         );

$res = $svc->register_method($method);


my $res4  = $svc->handle_request();

$struct = JSON::XS::decode_json((split("\n", $output))[-1]);

ok(  defined($struct->{input_params}{number}), 'non hidden input is defined');
ok( !defined($struct->{input_params}{hidden}), 'hidden input is not defined');

ok( defined $res4, 'help(method_name) works');

close(FH);

#--- Make sure the webservice module errors out when an optional parameter does not match it's pattern.
#--- Make it pass
open(FH, ">", \$output);

$svc = GRNOC::WebService::Dispatcher->new(
                                          test_input      => "method=number_echo&number=666&foobar=baz&date=2011-06-17",
                                          output_handle   => \*FH,
                                         );
ok( defined($svc) && ref $svc eq 'GRNOC::WebService::Dispatcher', 'Dispatcher->new() works');

$res = $svc->register_method($method);

ok( defined($res), 'Dispatcher->regiser_method() works');

$res2  = $svc->handle_request();

@input = split(/\n/, $output);

$struct = JSON::XS::decode_json($input[scalar(@input)-1]);

ok($struct->{'text'} eq "input text: 666 date: 2011-06-17" ,"JSON output seems correct");

close(FH);



#--- Make it fail
open(FH, ">", \$output);

$svc = GRNOC::WebService::Dispatcher->new(
                                          test_input      => "method=number_echo&number=666&foobar=baz&date=2011-6-17",
                                          output_handle   => \*FH,
                                         );
ok( defined($svc) && ref $svc eq 'GRNOC::WebService::Dispatcher', 'Dispatcher->new() works');

$res = $svc->register_method($method);

ok( defined($res), 'Dispatcher->regiser_method() works');

$res2  = $svc->handle_request();

@input = split(/\n/, $output);

$struct = JSON::XS::decode_json($input[scalar(@input)-1]);

like($struct->{'error_text'}, "/CGI input parameter date does not match pattern/" ,"JSON output seems correct");

close(FH);



###

open(FH, ">", \$output);

$svc = GRNOC::WebService::Dispatcher->new(
                                          test_input      => "method=number_echo&number=6",
                                          output_handle   => \*FH,
                                         );
ok( defined($svc) && ref $svc eq 'GRNOC::WebService::Dispatcher', 'Dispatcher->new() works');

$res = $svc->register_method($method);

ok( defined($res), 'Dispatcher->regiser_method() works');

$res2  = $svc->handle_request();

@input = split(/\n/, $output);

$struct = JSON::XS::decode_json($input[scalar(@input)-1]);

like($struct->{'error_text'}, "/is shorter than/" , "minimum length");

close(FH);



###

open(FH, ">", \$output);

$svc = GRNOC::WebService::Dispatcher->new(
                                          test_input      => "method=number_echo&number=6666666666666",
                                          output_handle   => \*FH,
                                         );
ok( defined($svc) && ref $svc eq 'GRNOC::WebService::Dispatcher', 'Dispatcher->new() works');

$res = $svc->register_method($method);

ok( defined($res), 'Dispatcher->regiser_method() works');

$res2  = $svc->handle_request();

@input = split(/\n/, $output);

$struct = JSON::XS::decode_json($input[scalar(@input)-1]);

like($struct->{'error_text'}, "/is longer than/" , "maximum length");

close(FH);


###

open(FH, ">", \$output);

$svc = GRNOC::WebService::Dispatcher->new(
                                          test_input      => "method=number_echo&number=666&foobar=baz&comment=blahblah\nblahblah\r\nblah",
                                          output_handle   => \*FH,
                                         );
ok( defined($svc) && ref $svc eq 'GRNOC::WebService::Dispatcher', 'Dispatcher->new() works');

$res = $svc->register_method($method);

ok( defined($res), 'Dispatcher->regiser_method() works');

$res2  = $svc->handle_request();

@input = split(/\n/, $output);

$struct = JSON::XS::decode_json($input[scalar(@input)-1]);

like($struct->{'text'} , "/blahblah\nblahblah\r\nblah/", "JSON output seems correct");

close( FH );

###

open(FH, ">", \$output);


$svc = GRNOC::WebService::Dispatcher->new(
                                             test_input   => "method=number_echo&number= \t 777 \t &foobar=baz",
                                             output_handle  => \*FH,
    );

$res = $svc->register_method($method);

$res2  = $svc->handle_request();

@input = split(/\n/, $output);

$struct = JSON::XS::decode_json($input[scalar(@input)-1]);


is( $struct->{'text'}, "input text: 777", "automatically trim leading and trailing whitespace" );

close(FH);

###

open(FH, ">", \$output);

$svc = GRNOC::WebService::Dispatcher->new(
    test_input      => "ourmethod=number_echo&number=666&foobar=baz",
    method_selector => ["ourmethod"],
    output_handle   => \*FH,
);

$res = $svc->register_method($method);

$res2  = $svc->handle_request();

@input = split(/\n/, $output);

$struct = JSON::XS::decode_json($input[scalar(@input)-1]);

ok($struct->{'text'} eq "input text: 666", "JSON output seems correct");

close(FH);
