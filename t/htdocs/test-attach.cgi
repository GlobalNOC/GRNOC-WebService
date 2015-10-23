#!/usr/bin/perl

use strict;
use lib '../../blib/lib';
use GRNOC::WebService;
use Digest::MD5;

my $svc = GRNOC::WebService::Dispatcher->new(allowed_proxy_users => ['blah']);

sub mp_test1_method {
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

sub mp_test2_method {
    my $meth_ref = shift;
    my $p_ref = shift;
    my $state_ref = shift;
    my $count = scalar @{$p_ref->{'files'}{'value'}};
    my @meta;
    my %res;

    my $ctx = Digest::MD5->new;
    for (my $x = 0; $x < scalar @{$p_ref->{'files'}{'value'}}; $x++) {
        my $fh = $p_ref->{'files'}{'value'}[$x];
        my $filename = $p_ref->{'files'}{'filename'}[$x];
        my $mime_type = $p_ref->{'files'}{'mime_type'}[$x];

	$ctx->addfile($fh);

	my $entry = {
            filename  => $filename,
            mime_type => $mime_type,
	};

	push @meta, $entry;
    }

    $res{'results'} = {
        files => \@meta,
        count => $count,
        hash  => $ctx->hexdigest, 
    };

    return \%res;
}

my $method1 = GRNOC::WebService::Method->new(
    name         => 'mp_test1',
    description  => 'multipart test method 1',
    expires      => '-1d',
    callback     => \&mp_test1_method,
);

$method1->add_input_parameter(
    name        => 'file',
    pattern     => '(.+)',
    required    => 1,
    description => 'an attached file',
);

my $method2 = GRNOC::WebService::Method->new(
    name        => 'mp_test2',
    description => 'multipart test method 2',
    expires     => '-1d',
    callback    => \&mp_test2_method,
);

$method2->add_input_parameter(
    name        => 'files',
    pattern     => '(.+)',
    required    => 1,
    multiple    => 1,
    description => 'attached files',
);

$svc->register_method($method1);
$svc->register_method($method2);

$svc->handle_request();



