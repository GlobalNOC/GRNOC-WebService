#!/usr/bin/perl
use Test::Simple tests=>3;
use strict;
use GRNOC::WebService;
use JSON::XS;
use Data::Dumper;
use FindBin;;

my $output;

sub number_echo{
    my $mthod_obj = shift;
    my $params    = shift;
    my %results;
    $results{'text'} = "input text: ".$params->{'number'}{'value'};
    return \%results;
}

#1 --- test method when deprecated is not specified (default value is 0 ~ false) --------
open(FH, ">", \$output);
my $method1 = GRNOC::WebService::Method->new(
                                              name            => "number_echo",
                                              description     => "descr",
                                              callback        => \&number_echo,
                                              config_file     => "$FindBin::Bin/conf/pattern_conf1.xml"
                                            );
$method1->add_input_parameter(
                              name            => 'number',
                              pattern         => '^(tdlss+)$',
                              required        => 1,
                              description     => "integer input"
                            );;

open(FH, ">", \$output);
my $svc = GRNOC::WebService::Dispatcher->new(test_input      => "method=help&method_name=number_echo",
                                          output_handle   => \*FH,
                                          );
$svc->register_method($method1);

my $res  = $svc->handle_request();
my @input = split(/\n/, $output);
my $struct = JSON::XS::decode_json($input[scalar(@input)-1]);
ok( defined $struct->{'method_deprecated'}, 0);
close(FH);

#2 --- test method when deprecated is specified as 1 ~ true --------
open(FH, ">", \$output);
my $method2 = GRNOC::WebService::Method->new(
                                                name              => "number_echo",
                                                description       => "descr",
                                                callback          => \&number_echo,
                                                config_file       => "$FindBin::Bin/conf/pattern_conf1.xml",
                                                method_deprecated => 1
                                                );
$method2->add_input_parameter(
                                name            => 'number',
                                pattern         => '^(tdlss+)$',
                                required        => 1,
                                description     => "integer input"
                              );;

open(FH, ">", \$output);
$svc = GRNOC::WebService::Dispatcher->new(test_input      => "method=help&method_name=number_echo",
                                          output_handle   => \*FH,
                                          );
$svc->register_method($method2);

my $res2  = $svc->handle_request();
@input = split(/\n/, $output);
$struct = JSON::XS::decode_json($input[scalar(@input)-1]);
ok( defined $struct->{'method_deprecated'}, 1);
close(FH);

#3 --- test method when deprecated is specified as 0 ~ false --------
open(FH, ">", \$output);
my $method3 = GRNOC::WebService::Method->new(
                                              name              => "number_echo",
                                              description       => "descr",
                                              callback          => \&number_echo,
                                              config_file       => "$FindBin::Bin/conf/pattern_conf1.xml",
                                              method_deprecated => 0
                                            );
$method3->add_input_parameter(
                                name            => 'number',
                                pattern         => '^(tdlss+)$',
                                required        => 1,
                                description     => "integer input"
                              );;

open(FH, ">", \$output);
$svc = GRNOC::WebService::Dispatcher->new(test_input      => "method=help&method_name=number_echo",
                                          output_handle   => \*FH,
                                          );
$svc->register_method($method3);

my $res3  = $svc->handle_request();
@input = split(/\n/, $output);
$struct = JSON::XS::decode_json($input[scalar(@input)-1]);
ok( defined $struct->{'method_deprecated'}, 0);
close(FH);