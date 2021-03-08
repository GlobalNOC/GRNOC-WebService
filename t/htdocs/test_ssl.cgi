#!/usr/bin/perl

use strict;
use lib '../../blib/lib';
use GRNOC::WebService;

$ENV{'HTTPS'}=1;


my $svc = GRNOC::WebService::Dispatcher->new(allowed_proxy_users => ['blah']);

sub method{
    my $meth_ref 	= shift;
    my $p_ref 		= shift;
    my $state_ref 	= shift;

    return {results => {'test' => 123123}};
}

my $method = GRNOC::WebService::Method->new(
					    name         => 'test',
					    description  => 'tester',
					    expires      => '-1d',
					    output_type  => 'application/json',
					    callback     => \&method,
					    );

$svc->register_method($method);

sub get_error_response{
    my $meth_ref  	= shift;
    my $p_ref     	= shift;
    my $state_ref 	= shift;
	$meth_ref->set_error("this is an error");
    return ;
}

my $method = GRNOC::WebService::Method->new(
					    name         => 'get_error_response',
					    description  => 'get error response test method',
					    expires      => '-1d',
					    output_type  => 'application/json',
					    callback     => \&get_error_response,
					    );

$svc->register_method($method);

$svc->handle_request();

sub undef_callback {
    my $method = shift;
    my $params = shift;
    my $state  = shift;

    my $optional_value = $params->{'null_optional_parameter'}{'value'};
    my $required_value = $params->{'null_required_parameter'}{'value'};

    return {results => {"required_parameter" => $required_value,
			"optional_parameter" => $optional_value}};

}


$method = GRNOC::WebService::Method->new(
					 name         => 'undef_test',
					 description  => 'tester',
					 expires      => '-1d',
					 output_type  => 'application/json',
					 callback     => \&undef,
					 );

$method->add_input_parameter(
			     name         => "null_optional_parameter",
			     pattern      => '^(\d+)$',
			     required     => 0,
			     multiple     => 0,
			     description  => "An optional parameter to echo back.",
			     );

$method->add_input_parameter(
			     name         => "null_required_parameter",
			     pattern      => '^(\d+)$',
			     required     => 1,
			     multiple     => 0,
			     description  => "An optional parameter to echo back.",
			     );

$svc->register_method($method);
