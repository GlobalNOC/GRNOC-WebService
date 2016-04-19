#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 6;
use GRNOC::WebService;
use Data::Dumper;
use JSON::XS;
use FindBin;

my $output;
open(FH, ">", \$output);

my $remote_user = 'cds_user_test';
$ENV{'REMOTE_USER'} = $remote_user;

my $svc = GRNOC::WebService::Dispatcher->new(
                                          test_input => "method=remote_method&remote_webservice=http://localhost:8529/protected/test.cgi&remote_method_name=get_remote_user&remote_parameters=blah%3Dfoo%2520bar",
                                          output_handle => \*FH
                                          );

$svc->activate_remote_methods(
                              default_user         => 'blah',
                              default_pass         => 'foo',
                              default_realm        => 'bar',
                              allowed_webservices  => ["http://localhost:8529/protected/test.cgi"],
                              cookie_prefix        => $FindBin::Bin
                              );

$svc->handle_request();

close(FH);

my @input = split("\n", $output);
my $struct = JSON::XS::decode_json($input[scalar(@input)-1]);

ok(defined($struct),"Results were returned");
ok(defined($struct->{'results'}->{'remote_user'}), "Data looks ok");
is($struct->{'results'}->{'remote_user'}, $remote_user, "Data is good!!");


$output = "";
open(FH, ">", \$output);

$remote_user = '';
$ENV{'REMOTE_USER'} = $remote_user;

$svc = GRNOC::WebService::Dispatcher->new(
                                          test_input => "method=remote_method&remote_webservice=http://localhost:8529/protected/test.cgi&remote_method_name=get_remote_user&remote_parameters=blah%3Dfoo%2520bar",
                                          output_handle => \*FH
                                          );

$svc->activate_remote_methods(
                              default_user         => 'blah',
                              default_pass         => 'foo',
                              default_realm        => 'bar',
                              allowed_webservices  => ["http://localhost:8529/protected/test.cgi"],
                              cookie_prefix        => $FindBin::Bin
                              );

$svc->handle_request();

close(FH);

@input = split("\n", $output);
$struct = JSON::XS::decode_json($input[scalar(@input)-1]);

ok(defined($struct),"Results were returned");
ok(defined($struct->{'results'}->{'remote_user'}), "Data looks ok");
is($struct->{'results'}->{'remote_user'}, $remote_user, "Data is good!!");
