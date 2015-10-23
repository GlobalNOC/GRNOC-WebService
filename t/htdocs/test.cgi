#!/usr/bin/perl

use strict;
use lib '../../blib/lib';
use GRNOC::WebService;
use Data::Dumper;

my $svc = GRNOC::WebService::Dispatcher->new(allowed_proxy_users => ['blah']);

sub method{
    my $meth_ref  = shift;
    my $p_ref     = shift;
    my $state_ref = shift;

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



sub echo {
    my $meth_ref  = shift;
    my $p_ref     = shift;
    my $state_ref = shift;

    my $blah = $p_ref->{'blah'}{'value'};

    return {results => {'test' => $blah}};
}

$method = GRNOC::WebService::Method->new(name         => 'echo',
					 description  => 'echo tester',
					 expires      => '-1d',
					 output_type  => 'application/json',
					 callback     => \&echo,
    );


$method->add_input_parameter(name        => "blah",
			     pattern     => '^(.+)$',
			     required    => 1,
			     description => "it gets echoed back to you"
    );


$svc->register_method($method);

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

sub slow_callback {
    my $method = shift;
    my $params = shift;
    my $state  = shift;

    my $sleepiness = $params->{'sleep_time'}{'value'};

    sleep($sleepiness);

    return {results => [{'meow' => 1}]};
}

$method = GRNOC::WebService::Method->new(name         => 'slow',
					 description  => 'slow tester',
					 expires      => '-1d',
					 output_type  => 'application/json',
					 callback     => \&slow_callback,
    );


$method->add_input_parameter(name        => "sleep_time",
			     pattern     => '^(\d+)$',
			     required    => 1,
			     description => "the time in seconds to sleep"
    );


$svc->register_method($method);


sub lots_of_headers {
    my $method =  shift;
    my $params =  shift;
    my $state  = shift;

    my $extra_header = $params->{'extra_header'}{'value'};

    $method->set_headers([{name => 'foo', value => $extra_header},
                          {name => 'content-type', value => 'application/testing'}
                         ]);
                              

    return {results => [{'foo' => 'test'}]};
}


$method = GRNOC::WebService::Method->new(name         => 'headers',
					 description  => 'echos back an extra header',
					 expires      => '-1d',
					 output_type  => 'application/json',
					 callback     => \&lots_of_headers
    );


$method->add_input_parameter(name        => "extra_header",
			     pattern     => '^(\S+)$',
			     required    => 1,
			     description => "the value of the foo header"
    );

$svc->register_method($method);

sub encoded_keyvalues {
    my $method =  shift;
    my $params =  shift;
    my $state  = shift;

    my $object;

    foreach my $param_name (keys %$params){
        $object->{$param_name} = $params->{$param_name}{'value'};
    }

    return {results => $object};
}


$method = GRNOC::WebService::Method->new(name         => 'encoded_kv_pairs',
					 description  => 'Echoes back what the server got for encoded keys and values',
					 expires      => '-1d',
					 output_type  => 'application/json',
					 callback     => \&encoded_keyvalues
    );


$method->add_input_parameter(name        => "input with space",
			     pattern     => '^(.+)$',
			     required    => 1,
			     description => "the value"
    );


$svc->register_method($method);


$svc->handle_request();
