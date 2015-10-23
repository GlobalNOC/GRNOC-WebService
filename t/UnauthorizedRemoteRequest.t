#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 4;
use GRNOC::WebService;
use Data::Dumper;
use JSON::XS;
use FindBin;

my $output;

open(FH, ">", \$output);

my $svc = GRNOC::WebService::Dispatcher->new(
					     test_input      => "method=remote_urn_method&service_identifier=urn:publicid:IDN%2Bgrnoc.iu.edu:GlobalNOC:CDS:1:Node&remote_method_name=test&remote_parameters=&",
					     output_handle   => \*FH
					     );

$svc->activate_remote_methods(default_user             => 'blah',
			      default_pass             => 'foo',
			      default_realm            => 'bar',
			      allowed_webservice_urns  => ["urn:publicid:IDN+grnoc.iu.edu:GlobalNOC:CDS:1:Circuit"],
			      service_cache_file       => "$FindBin::Bin/conf/name_service.xml",
                              cookie_prefix            => $FindBin::Bin
			      );

$svc->handle_request();

my @input = split(/\n/, $output);

ok(@input, "got output");
like($input[0], qr/Status: 502/, "error code 502 returned");

close(FH);


open(FH, ">", \$output);

$svc = GRNOC::WebService::Dispatcher->new(
					  test_input => "method=remote_method&remote_webservice=http://localhost:8529/test.cgi&remote_method_name=test&remote_parameters=&",
					  output_handle => \*FH
					  );

$svc->activate_remote_methods(
                              default_user        => 'blah',
                              default_pass        => 'foo',
			      default_realm       => 'bar',
                              allowed_webservices => ["http://localhost:8529/test2.cgi"],
                              cookie_prefix       => $FindBin::Bin
                              );

$svc->handle_request();

@input = split(/\n/, $output);

ok(@input, "got output");
like($input[0], qr/Status: 502/, "error code 502 returned");

close(FH);
