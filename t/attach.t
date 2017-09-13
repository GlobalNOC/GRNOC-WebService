#!/usr/bin/perl

use Test::More;
use strict;
use GRNOC::WebService;
use Data::Dumper;
use HTTP::Request::Common;
use LWP::UserAgent;
use JSON;

####################################################
# test a single file

my $ua = new LWP::UserAgent;
my $res = $ua->request(POST 'http://localhost:8529/test-attach.cgi',
    Content_Type => 'form-data',
    Content      => [
        method => 'mp_test1',
        file   => [ 't/data/grnoc-logo.png', 'grnoc-logo.png' ]
    ],
);

ok($res->is_success, 'form data was posted to the web service');

my $ws_data = from_json($res->content);
my $filename = $ws_data->{'results'}{'filename'};
my $mime_type = $ws_data->{'results'}{'mime_type'};
my $hash = $ws_data->{'results'}{'hash'};

is($filename, 'grnoc-logo.png', 'single file post has correct filename');
is($mime_type, 'image/png', 'single file post has correct MIME type');
is($hash, 'da5e6e130c62f3da8b52dfdc9c05cb47', 'single file post has correct MD5 hash value (hex)');


####################################################
# test multiple files

$res = $ua->request(POST 'http://localhost:8529/test-attach.cgi',
    Content_Type => 'form-data',
    Content      => [
        'method',
        'mp_test2',
        'files',
        [ 't/data/grnoc-logo.png',  'grnoc-logo.png'  ],
        'files',
        [ 't/data/iLight-logo.png', 'iLight-logo.png' ],
        'files',
        [ 't/data/ipgrid-logo.png', 'ipgrid-logo.png' ],
        'files',
        [ 't/data/iu_signature.png', 'iu_signature.png' ],
        'files',
        [ 't/data/SDNLab_header_0.jpg' , 'SDNLab_header_0.jpg' ],
    ],
);

ok($res->is_success, 'form data with multiple files was posted to the web service');

$ws_data = from_json($res->content);
my $files = $ws_data->{'results'}{'files'};

is($files->[0]{'filename'}, 'grnoc-logo.png', 'multiple file post has correct filename for file 1');
is($files->[1]{'filename'}, 'iLight-logo.png', 'multiple file post has correct filename for file 2');
is($files->[2]{'filename'}, 'ipgrid-logo.png', 'multiple file post has correct filename for file 3');
is($files->[3]{'filename'}, 'iu_signature.png', 'multiple file post has correct filename for file 4');
is($files->[4]{'filename'}, 'SDNLab_header_0.jpg', 'multiple file post has correct filename for file 5');

for (my $x = 0; $x < 4; $x++) {
    is($files->[$x]{'mime_type'}, 'image/png', 'multiple file post has correct MIME type for file ' . ($x + 1));
}
is($files->[4]{'mime_type'}, 'image/jpeg', 'multiple file post has correct MIME type for file 5');

is($ws_data->{'results'}{'hash'}, '39d52ddc4891e939b656dafae537f9b3', 'multiple file post has correct MD5 hash value (hex) for all files');


####################################################
# test file size limit


# TODO: There is a problem with the following not being tested
# 100% reliably under EL7. I think this may have to do with
# apache2.4 and the test harness closing since it seems
# to work about 50% of the time and fail 50% of the time.
# As this is an edge case both in terms of file upload AND
# too big files, I feel this is safe to open a new issue on.
if (`uname -a` =~ /\.el7/){
    diag("Skipping oversized fileupload tests on el7, see TODO comments");
    done_testing();
    exit(0);
}

$res = $ua->request(POST 'http://localhost:8529/test-attach2.cgi',
    Content_Type => 'form-data',
    Content      => [
        method => 'mp_test1',
        file   => [ 't/data/grnoc-logo.png', 'grnoc-logo.png' ]
    ],
);

ok($res->is_success, 'form data with a file that is too large was posted to the web service');

my $ws_err = from_json($res->content);
is($ws_err->{'error'}, 1, 'the web service did not accept a file that is too large');

my $err_text = $ws_err->{'error_text'};
ok($err_text =~ /^413/, 'the web service returned a CGI error with HTTP status code 413');

done_testing();
