#!/usr/bin/perl

use strict;
use lib '../../../blib/lib';
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


sub get_remote_user{
    my $meth_ref  = shift;
    my $p_ref     = shift;
    my $state_ref = shift;

    my $remote_user = $ENV{'REMOTE_USER'};

    return {results => {'remote_user' => $remote_user}};
}

$method = GRNOC::WebService::Method->new(
                                          name         => 'get_remote_user',
                                          description  => 'Test remote user',
                                          expires      => '-1d',
                                          output_type  => 'application/json',
                                          callback     => \&get_remote_user,
                                        );

$svc->register_method($method);

$svc->handle_request();
