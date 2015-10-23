#!/usr/bin/perl

use strict;
use lib '../../blib/lib';
use GRNOC::WebService;
use Digest::MD5;

my $svc = GRNOC::WebService::Dispatcher->new(
    allowed_proxy_users => ['blah'],
    max_post_size => 10000,
);

sub mp_test_method {
    my $meth_ref = shift;
    my $p_ref = shift;
    my $state_ref = shift;
    my %res;

    my $filename = $p_ref->{'file'}{'filename'};
    my $mime_type = $p_ref->{'file'}{'mime_type'};

    my $ctx = Digest::MD5->new;
    $ctx->addfile($p_ref->{'file'}{'value'});
    my $hash = $ctx->hexdigest;

    $res{'results'} = {
        filename  => $filename,
        mime_type => $mime_type,
        hash      => $hash,
    };

    return \%res;
}

my $method1 = GRNOC::WebService::Method->new(
    name          => 'mp_test1',
    description   => 'multipart test method 1',
    expires       => '-1d',
    callback      => \&mp_test_method,
);

$method1->add_input_parameter(
    name        => 'file',
    pattern     => '(.+)',
    required    => 1,
    description => 'an attached file',
);

$svc->register_method($method1);

$svc->handle_request();



