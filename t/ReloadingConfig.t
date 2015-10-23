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

$svc->activate_remote_methods(default_user            => 'blah',
			      default_pass            => 'foo',
			      allowed_webservice_urns => ["urn:publicid:IDN+grnoc.iu.edu:GlobalNOC:CDS:1:Node"],
			      service_cache_file      => "$FindBin::Bin/conf/name_service.xml",
                              cookie_prefix           => $FindBin::Bin
			      );

# dig dig dig to pull out the client, we need to test whether it updates the config
my $client    = $svc->{'methods'}{'remote_urn_method'}->{'client'};

my $last_load = $svc->{'methods'}{'remote_urn_method'}->{'config_mtime'};

sleep(1);

# handle request triggers the client to load its config
$svc->handle_request();

is(scalar keys %{$client->{'service_urls'}}, 2, "checking for existence of only 2 service urls");


# now let's change the mtime of the file
my $now = time;

utime($now, $now, "$FindBin::Bin/conf/name_service.xml") or die "Unable to set atime/mtime on name_service.xml";

# trigger another request that should detect that the mtime is now more recent and reload the config
$svc->handle_request();

ok($last_load != $svc->{'methods'}{'remote_urn_method'}->{'config_mtime'}, "checking to see that last config read time has changed");

ok($now == $svc->{'methods'}{'remote_urn_method'}->{'config_mtime'}, "checking to see that last config read time has changed");

is(scalar keys %{$client->{'service_urls'}}, 2, "checking for existence of only 2 service urls");

close(FH);
