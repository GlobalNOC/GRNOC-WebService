#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 21;
use GRNOC::WebService;
use Data::Dumper;
use JSON::XS;
use FindBin;

my $output;
my $results;

open(FH, ">", \$output);

my $svc = GRNOC::WebService::Dispatcher->new(
					     test_input      => "method=remote_urn_method&service_identifier=urn:publicid:IDN%2Bgrnoc.iu.edu:GlobalNOC:CDS:1:Node&remote_method_name=test&remote_parameters=&",
					     output_handle   => \*FH
					     );

# specific credentials mapped to a particular URN and a URL to override the defaults
my $specific_credentials = {

    "urn:publicid:IDN+grnoc.iu.edu:GlobalNOC:CDS:1:Node" => {"username" => "something_else",
							     "password" => "another",
							     "realm"    => "diff realm"
							     },

    # this one is deliberately missing realm, it should inherit it from the defaults								 
    "http://localhost:8529/test.cgi"                     => {"username" => "faux_name",
							     "password" => "i_dont_know",
							     }
							     
					 
};

$svc->activate_remote_methods(default_user             => 'blah',
			      default_pass             => 'foo',
			      default_realm            => 'bar',
			      specific_credentials     => $specific_credentials,
                              allowed_webservices      => ["http://localhost:8529/test.cgi"],
			      allowed_webservice_urns  => ["urn:publicid:IDN+grnoc.iu.edu:GlobalNOC:CDS:1:Node",
							   "urn:publicid:IDN+grnoc.iu.edu:GlobalNOC:CDS:1:Pop",
							   ],
			      service_cache_file       => "$FindBin::Bin/conf/name_service.xml",
                              cookie_prefix            => $FindBin::Bin    
			      );

my $client = $svc->{'methods'}->{'remote_urn_method'}->{'client'};

is($client->{'uid'},    "blah", "initial username");
is($client->{'passwd'}, "foo",  "initial password");
is($client->{'realm'},  "bar",  "initial realm");

$svc->handle_request();

ok(defined($output),"Results were returned");

my @lines = split(/\n/,  $output);

$results = decode_json($lines[scalar(@lines)-1]);

ok(defined($results->{'results'}->{'test'}), "Data looks ok");
ok($results->{'results'}->{'test'} == 123123, "Data is good!!");

# after that request, the client should have changed its credentials because it matched a specific
# credential given for this URN
is($client->{'uid'},    "something_else", "changed username credentials");
is($client->{'passwd'}, "another",        "changed password credentials");
is($client->{'realm'},  "diff realm",     "changed realm credentials");

undef $output;

# switch over to using the Pop method which does not have a specific credentials
# entry and it should revert to using the defaults
$svc->{'test_input'} = "method=remote_urn_method&service_identifier=urn:publicid:IDN%2Bgrnoc.iu.edu:GlobalNOC:CDS:1:Pop&remote_method_name=test&remote_parameters=&";

$svc->handle_request();

ok(defined($output),"Results were returned");

@lines = split(/\n/, $output);

$results = decode_json($lines[scalar(@lines)-1]);

ok(defined($results->{'results'}->{'test'}), "Data looks ok");
ok($results->{'results'}->{'test'} == 123123, "Data is good!!");

is($client->{'uid'},    "blah", "changed back to default username");
is($client->{'passwd'}, "foo",  "changed back to default password");
is($client->{'realm'},  "bar",  "changed back to default realm");

undef $output;

# now switch over to using the URL both to test that it works for URLs too and that we
# have inheritance of the attributes. The URL only has username / password defined in specific
# credentials, so it should inherit the realm.
$client = $svc->{'methods'}->{'remote_method'}->{'client'};

$svc->{'test_input'} = "method=remote_method&remote_webservice=http%3A%2F%2Flocalhost%3A8529%2Ftest.cgi&remote_method_name=test&remote_parameters=&";

$svc->handle_request();

ok(defined($output),"Results were returned");

@lines = split(/\n/, $output);

$results = decode_json($lines[scalar(@lines)-1]);

ok(defined($results->{'results'}->{'test'}), "Data looks ok");
ok($results->{'results'}->{'test'} == 123123, "Data is good!!");

is($client->{'uid'},    "faux_name",    "changed username credentials");
is($client->{'passwd'}, "i_dont_know",  "changed password credentials");
is($client->{'realm'},  "bar",          "inherited default realm");

close(FH);
