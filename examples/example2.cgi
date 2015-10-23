#!/usr/bin/perl
use strict;
use GRNOC::WebService;

#--- first we set define a confg struct for the method
#--- this is used to determine which parameters we pass in
my $number_echo_cfg = {
			  parameters =>{
				number => {
					pattern 	=> '^(\d+)$',
					required 	=>  1
				}
			  },
			  expires => "-1d",

			};

#--- this is the function that we will be called by the web service object
sub number_echo{
	my $params = shift;

	my %results;

	$results{'text'} = "input text: ".$params->{'number'}{'value'};

	return \%results;
}

#--- create the web service
my $svc = GRNOC::WebService->new();

#--- register the method, binding the parameter config, method name and function
$svc->register_method("number_echo",\&number_echo, $number_echo_args);

#--- let the web service do its thing
$svc->handle_request();

