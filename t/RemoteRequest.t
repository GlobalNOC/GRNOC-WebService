#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 18;
use GRNOC::WebService;
use Data::Dumper;
use JSON::XS;
use FindBin;

my $output;

open(FH, ">", \$output);

my $svc = GRNOC::WebService::Dispatcher->new(
					     test_input      => "method=remote_urn_method&service_identifier=urn:publicid:IDN%2Bgrnoc.iu.edu:GlobalNOC:CDS:1:Node&remote_method_name=echo&remote_parameters=blah%3Dthis%2520has%2520spaces%2520and%2520%253E",
					     output_handle   => \*FH
					     );

$svc->activate_remote_methods(
			      default_user             => 'blah',
			      default_pass             => 'foo',
			      default_realm            => 'bar',
			      allowed_webservice_urns  => ["urn:publicid:IDN+grnoc.iu.edu:GlobalNOC:CDS:1:Node"],
			      service_cache_file       => "$FindBin::Bin/conf/name_service.xml",
                              cookie_prefix            => $FindBin::Bin
			      );

$svc->handle_request();

close(FH);

my @input = split("\n", $output);

my $struct = JSON::XS::decode_json($input[scalar(@input)-1]);

ok(defined($struct),"Results were returned");
ok(defined($struct->{'results'}->{'test'}), "Data looks ok");
is($struct->{'results'}->{'test'}, "this has spaces and >", "Data is good!!");

$output = "";


open(FH, ">", \$output);

$svc = GRNOC::WebService::Dispatcher->new(
					  test_input => "method=remote_method&remote_webservice=http://localhost:8529/test.cgi&remote_method_name=echo&remote_parameters=blah%3Dfoo%2520bar",
					  output_handle => \*FH
					  );

$svc->activate_remote_methods(
			      default_user         => 'blah',
			      default_pass         => 'foo',
			      default_realm        => 'bar',
                              allowed_webservices  => ["http://localhost:8529/test.cgi"],
                              cookie_prefix        => $FindBin::Bin
                              );

$svc->handle_request();

close(FH);


@input = split("\n", $output);

$struct = JSON::XS::decode_json($input[scalar(@input)-1]);

ok(defined($struct),"Results were returned");
ok(defined($struct->{'results'}->{'test'}), "Data looks ok");
is($struct->{'results'}->{'test'}, "foo bar", "Data is good!!");

$output = "";


open(FH, ">", \$output);

$svc = GRNOC::WebService::Dispatcher->new(
                                           test_input => "method=remote_urn_lookup&service_identifier=urn:publicid:IDN%2Bgrnoc.iu.edu:GlobalNOC:CDS:1:Node",
                                           output_handle => \*FH
					  );

$svc->activate_remote_methods(
			      default_user         => 'blah',
			      default_pass         => 'foo',
			      default_realm        => 'bar',
                              allowed_webservice_urns => ["urn:publicid:IDN+grnoc.iu.edu:GlobalNOC:CDS:1:Node"],
			      service_cache_file      => "$FindBin::Bin/conf/name_service.xml",
                              cookie_prefix => $FindBin::Bin
                              );

$svc->handle_request();

close(FH);

@input = split("\n", $output);

$struct = JSON::XS::decode_json($input[scalar(@input)-1]);

ok(defined($struct),"Results were returned");
ok(defined($struct->{'results'}), "Data looks ok");
is($struct->{'results'}->[0]->{'url'}, "http://localhost:8529/test.cgi", "Data is good!!");
is($struct->{'results'}->[0]->{'weight'}, "1", "Data is good!!");

# now test the slow webservice and tweaking our timeout values
# this first request should timeout since we specified a timeout of 2 and a sleep of 5 seconds
$output = "";

open(FH, ">", \$output);

$svc = GRNOC::WebService::Dispatcher->new(
                                           test_input => "method=remote_method&remote_webservice=http://localhost:8529/test.cgi&timeout=2&remote_method_name=slow&remote_parameters=sleep_time%3D5",
                                           output_handle => \*FH
					  );

$svc->activate_remote_methods(
			      default_user         => 'blah',
			      default_pass         => 'foo',
			      default_realm        => 'bar',
                              allowed_webservices  => ["http://localhost:8529/test.cgi"],
                              cookie_prefix => $FindBin::Bin
                              );

$svc->handle_request();

close(FH);

like($output, '/Status: 502/', "verified got timed out request (URL)");

# this second request should pass since we default to a timeout of 15sec and a sleep of 5 seconds
$output = "";

open(FH, ">", \$output);

$svc = GRNOC::WebService::Dispatcher->new(
                                           test_input => "method=remote_method&remote_webservice=http://localhost:8529/test.cgi&remote_method_name=slow&remote_parameters=sleep_time%3D5",
                                           output_handle => \*FH
					  );

$svc->activate_remote_methods(
			      default_user         => 'blah',
			      default_pass         => 'foo',
			      default_realm        => 'bar',
                              allowed_webservices  => ["http://localhost:8529/test.cgi"],
                              cookie_prefix => $FindBin::Bin
                              );

$svc->handle_request();

close(FH);

@input = split("\n", $output);

$struct = JSON::XS::decode_json($input[scalar(@input)-1]);

ok(defined($struct),"Results were returned");
ok(defined($struct->{'results'}), "Data looks ok");
is($struct->{'results'}->[0]->{'meow'}, "1", "Got right data back");

# do the same thing with slowness testing but with a URN instead of a URL, this should time out
$output = "";

open(FH, ">", \$output);

$svc = GRNOC::WebService::Dispatcher->new(
                                           test_input => "method=remote_urn_method&service_identifier=urn:publicid:IDN%2Bgrnoc.iu.edu:GlobalNOC:CDS:1:Node&remote_method_name=slow&timeout=2&remote_parameters=sleep_time%3D5",
                                           output_handle => \*FH
					  );

$svc->activate_remote_methods(
			      default_user             => 'blah',
			      default_pass             => 'foo',
			      default_realm            => 'bar',
			      allowed_webservice_urns  => ["urn:publicid:IDN+grnoc.iu.edu:GlobalNOC:CDS:1:Node"],
			      service_cache_file       => "$FindBin::Bin/conf/name_service.xml",
                              cookie_prefix => $FindBin::Bin
			      );


$svc->handle_request();

close(FH);

like($output, '/Status: 502/', "verified got timed out request (URN)");


# do the same thing with slowness testing but with a URN instead of a URL, this should NOT time out
$output = "";

open(FH, ">", \$output);

$svc = GRNOC::WebService::Dispatcher->new(
                                           test_input => "method=remote_urn_method&service_identifier=urn:publicid:IDN%2Bgrnoc.iu.edu:GlobalNOC:CDS:1:Node&remote_method_name=slow&remote_parameters=sleep_time%3D5",
                                           output_handle => \*FH
					  );

$svc->activate_remote_methods(
			      default_user             => 'blah',
			      default_pass             => 'foo',
			      default_realm            => 'bar',
			      allowed_webservice_urns  => ["urn:publicid:IDN+grnoc.iu.edu:GlobalNOC:CDS:1:Node"],
			      service_cache_file       => "$FindBin::Bin/conf/name_service.xml",
                              cookie_prefix => $FindBin::Bin
			      );


$svc->handle_request();

close(FH);

@input = split("\n", $output);

$struct = JSON::XS::decode_json($input[scalar(@input)-1]);

ok(defined($struct),"Results were returned");
ok(defined($struct->{'results'}), "Data looks ok");
is($struct->{'results'}->[0]->{'meow'}, "1", "Got right data back");
