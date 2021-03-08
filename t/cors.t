#!/usr/bin/perl
use Test::Simple tests => 18;

use HTTP::Request;
use HTTP::Headers;
use Data::Dumper;
require LWP::UserAgent;
use JSON::XS;

use strict;
use warnings;

my $local_port=8529;
my $ua;
my $request;
my $response;
my $good_site='https://someserver.grnoc.iu.edu';
my $evil_site='https://grnoc.iu.edu.facebook.com';
my $result_struct;


######################################################
# Do prep
#
#Headers 
my $good_header= HTTP::Headers->new;


$good_header->header('Origin' => $good_site);
$good_header->header('Access-Control-Request-Method' => 'GET');
$good_header->header('Access-Control-Request-Headers' => 'Origin, X-Requested-With');

my $evil_header= HTTP::Headers->new;
$evil_header->header('Origin' => $evil_site);
$evil_header->header('Access-Control-Request-Method' => 'GET');
$evil_header->header('Access-Control-Request-Headers' => 'Origin, X-Requested-With');

################################

#check basic request (orgin + access_control_request_method on options request) 
$request=HTTP::Request->new("OPTIONS","http://localhost:$local_port/test.cgi?method=test",$good_header);
$ua = LWP::UserAgent->new;
$response=$ua->request($request);
#warn Dumper($request);
#warn Dumper($response);
ok(
   ($response->header('access-control-allow-origin') eq $good_site)          and 
   ($response->header('access-control-allow-credentials') eq 'false')        and
   ($response->header('access-control-allow-headers') eq 'X-Requested-With')
  );



#now check that evil header gets blocked
$request=HTTP::Request->new("OPTIONS","http://localhost:$local_port/test.cgi?method=test",$evil_header);
$ua = LWP::UserAgent->new;
$response=$ua->request($request);
#warn Dumper($request);
#warn Dumper($response);

ok(
   ($response->header('access-control-allow-origin') ne $evil_site) and
   ($response->header('access-control-allow-origin') ne '*' ));



#check basic request (origin +access_control on GET)
$request=HTTP::Request->new("GET","http://localhost:$local_port/test.cgi?method=test",$good_header);
$ua = LWP::UserAgent->new;
$response=$ua->request($request);
#warn Dumper($request);
# warn Dumper($response);
ok(
   ($response->header('access-control-allow-origin') eq $good_site)          and 
   ($response->header('access-control-allow-credentials') eq 'false')        
  );

$result_struct = JSON::XS::decode_json($response->content());

ok(defined($result_struct),"Results were returned");
ok(defined($result_struct->{'results'}->{'test'}), "Data looks ok");
ok($result_struct->{'results'}->{'test'} == 123123, "Data is good!!");



#repeat for evil site
$request=HTTP::Request->new("GET","http://localhost:$local_port/test.cgi?method=test",$evil_header);
$ua = LWP::UserAgent->new;
$response=$ua->request($request);
#warn Dumper($request);
#warn Dumper($response);
ok(
       ($response->header('access-control-allow-origin') ne $evil_site)         
   and ($response->header('access-control-allow-origin') ne '*' ) 
   and ($response->header('access-control-allow-credentials') eq 'false')
  );

# test error for CORS settings
# good_site 
$request=HTTP::Request->new("GET","http://localhost:$local_port/test.cgi?method=get_error_response",$good_header);
$ua = LWP::UserAgent->new;
$response=$ua->request($request);
#warn Dumper($request);
# warn Dumper($response);
ok(
   ($response->header('access-control-allow-origin') eq $good_site)          and 
   ($response->header('access-control-allow-credentials') eq 'false')        and
   ($response->header('access-control-allow-headers') eq 'X-Requested-With')
  );

# test error for CORS settings
# evil_site 
$request=HTTP::Request->new("GET","http://localhost:$local_port/test.cgi?method=get_error_response",$evil_header);
$ua = LWP::UserAgent->new;
$response=$ua->request($request);
#warn Dumper($request);
# warn Dumper($response);
ok(
  ($response->header('access-control-allow-origin') ne $evil_site) and
   ($response->header('access-control-allow-origin') ne '*' )
  );

#####################################################################################


#now we repeat the tests with fake ssl
#check basic request (orgin + access_control_request_method on options request) 
$request=HTTP::Request->new("OPTIONS","http://localhost:$local_port/test_ssl.cgi?method=test",$good_header);
$ua = LWP::UserAgent->new;
$response=$ua->request($request);
#warn Dumper($request);
#warn Dumper($response);
ok(
   ($response->header('access-control-allow-origin') eq $good_site)         and
   ($response->header('access-control-allow-credentials') eq 'true')        and
   ($response->header('access-control-allow-headers') eq 'X-Requested-With')
  );



#now check that evil header gets blocked
$request=HTTP::Request->new("OPTIONS","http://localhost:$local_port/test_ssl.cgi?method=test",$evil_header);
$ua = LWP::UserAgent->new;
$response=$ua->request($request);
#warn Dumper($request);
#warn Dumper($response);

ok(
   ($response->header('access-control-allow-origin') ne $evil_site) and
   ($response->header('access-control-allow-origin') ne '*' ) and 
   ($response->header('access-control-allow-credentials') eq 'false') );

#check basic request (origin +access_control on GET)
$request=HTTP::Request->new("GET","http://localhost:$local_port/test_ssl.cgi?method=test",$good_header);
$ua = LWP::UserAgent->new;
$response=$ua->request($request);
#warn Dumper($request);
#warn Dumper($response);
ok(
   ($response->header('access-control-allow-origin') eq $good_site)          and
   ($response->header('access-control-allow-credentials') eq 'true')
  );

 $result_struct = JSON::XS::decode_json($response->content());

ok(defined($result_struct),"Results were returned");
ok(defined($result_struct->{'results'}->{'test'}), "Data looks ok");
ok($result_struct->{'results'}->{'test'} == 123123, "Data is good!!");

#repeat for evil site
$request=HTTP::Request->new("GET","http://localhost:$local_port/test_ssl.cgi?method=test",$evil_header);
$ua = LWP::UserAgent->new;
$response=$ua->request($request);
#warn Dumper($request);
# warn Dumper($response);
ok(
       ($response->header('access-control-allow-origin') ne $evil_site)
   and ($response->header('access-control-allow-origin') ne '*' )
   and ($response->header('access-control-allow-credentials') eq 'false')
  );

# test error for CORS settings
# good_site 
$request=HTTP::Request->new("GET","http://localhost:$local_port/test_ssl.cgi?method=get_error_response",$good_header);
$ua = LWP::UserAgent->new;
$response=$ua->request($request);
#warn Dumper($request);
# warn Dumper($response);
ok(
   ($response->header('access-control-allow-origin') eq $good_site)     and           
   ($response->header('access-control-allow-credentials') eq 'true')    and       
   ($response->header('access-control-allow-headers') eq 'X-Requested-With')
);
  

# test error for CORS settings
# evil_site 
$request=HTTP::Request->new("GET","http://localhost:$local_port/test_ssl.cgi?method=get_error_response",$evil_header);
$ua = LWP::UserAgent->new;
$response=$ua->request($request);
#warn Dumper($request);
# warn Dumper($response);
ok(
   ($response->header('access-control-allow-origin') ne $evil_site)  and
   ($response->header('access-control-allow-origin') ne '*' )        and
   ($response->header('access-control-allow-credentials') eq 'false')
);






