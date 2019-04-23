#!/usr/bin/perl
use Test::Simple tests=>4;
use strict;
use GRNOC::WebService;
use JSON::XS;
use Data::Dumper;

my $output;

sub number_echo{
    my $mthod_obj = shift;
    my $params    = shift;
    my %results;
    $results{'text'} = "input text: ".$params->{'number'}{'value'};
    return \%results;
}

#1 --- test when enable_pattern_introspection is set to 1 --------

# a) --- test error output ------
open(FH, ">", \$output);
my $method2 = GRNOC::WebService::Method->new(
                                                name            => "number_echo2",
                                                description     => "descr",
                                                callback        => \&number_echo,
                                                config_file     => "../t/conf/pattern_conf1.xml"
                                                );
$method2->add_input_parameter(
                                name            => 'number',
                                pattern         => '^(tdlss+)$',
                                required        => 1,
                                description     => "integer input"
                              );;
my $pattern = '^(tdlss+)$';
my $svc = GRNOC::WebService::Dispatcher->new(
                                        test_input      => "method=number_echo2&number=op",
                                        output_handle   => \*FH
                                        );
$svc->register_method($method2);
$svc->handle_request();
my @input = split(/\n/, $output);
my $struct = JSON::XS::decode_json($input[scalar(@input)-1]);
ok($struct->{'error_text'} eq "number_echo2: CGI input parameter number does not match pattern /$pattern/" ,"1a - error output pattern check correct");

# b) --- test help output ------

open(FH, ">", \$output);
$svc = GRNOC::WebService::Dispatcher->new(test_input      => "method=help&method_name=number_echo2",
                                          output_handle   => \*FH,
                                          );
$svc->register_method($method2);
my $res2  = $svc->handle_request();
@input = split(/\n/, $output);
$struct = JSON::XS::decode_json($input[scalar(@input)-1]);
ok( defined $struct->{'input_params'}->{'number'}->{'pattern'}, "1b - help output pattern check correct");
close(FH);



#2 --- test when enable_pattern_introspection is set to 0 --------

# a) --- test error output ------
open(FH, ">", \$output);
my $method1 = GRNOC::WebService::Method->new(
                                                name            => "number_echo3",
                                                description     => "descr",
                                                callback        => \&number_echo,
                                                config_file     => "../t/conf/pattern_conf0.xml"
    );
$method1->add_input_parameter(
                                name            => 'number',
                                pattern         => '^(tdlss+)$',
                                required        => 1,
                                description     => "integer input"
                              );;
my $pattern = '^(tdlss+)$';
my $svc2 = GRNOC::WebService::Dispatcher->new(
                                        test_input      => "method=number_echo3&number=op",
                                        output_handle   => \*FH
                                        );
$svc2->register_method($method1);
$svc2->handle_request();
my @input = split(/\n/, $output);
my $struct = JSON::XS::decode_json($input[scalar(@input)-1]);
ok($struct->{'error_text'} eq "number_echo3: CGI input parameter number does not match pattern" ,"2a - pattern check correct");


# b) --- test help output ------

open(FH, ">", \$output);
$svc = GRNOC::WebService::Dispatcher->new(test_input      => "method=help&method_name=number_echo2",
                                          output_handle   => \*FH,
    );
$svc->register_method($method1);
$svc->handle_request();
@input = split(/\n/, $output);
$struct = JSON::XS::decode_json($input[scalar(@input)-1]);
ok( !defined $struct->{'input_params'}->{'number'}->{'pattern'}, "2b - help pattern check correct");
close(FH);
