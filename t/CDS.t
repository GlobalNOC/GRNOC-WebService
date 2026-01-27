use strict;
use warnings;

use Test::More tests => 11;

use GRNOC::WebService;
use GRNOC::WebService::Method::CDS;
use JSON::XS;
use Data::Dumper;

# Callback function for testing input parameter handling
sub callback {
    my ( $method, $args ) = @_;

    #my $regex_args = {};
    #foreach my $k (qw(test_param_regex test_param_not_regex)) {
    #    if (exists $args->{$k} && (defined $args->{$k}{'value'} || $args->{$k}{'is_set'})) {
    #        $regex_args->{$k} = $args->{$k};
    #    }
    #}
    #warn "REGEX ARGS: " . Dumper($regex_args);

    my $value;
    if ($args->{'test_param_greater_equal'} && $args->{'test_param_greater_equal'}{'is_set'}) {
        $value = $args->{'test_param_greater_equal'}{'value'};
    } elsif ($args->{'test_param_regex'} && $args->{'test_param_regex'}{'is_set'}) {
        $value = $args->{'test_param_regex'}{'value'};
    } elsif ($args->{'test_param_not_regex'} && $args->{'test_param_not_regex'}{'is_set'}) {
        $value = $args->{'test_param_not_regex'}{'value'};
    } else {
        $value = ['none'];
    }
    $value = [$value] unless ref $value eq 'ARRAY';
    return {'results' => [{'test_param' => $value}]};
}

# ===== TEST SECTION: Method Creation =====
my $method = GRNOC::WebService::Method::CDS->new(
    name => 'cds_test',
    description => "CDS test method",
    expires => "-1d",
    callback => \&callback,
    default_order_by => 'test_order_by',
    default_order => 'DESC'
);

ok( defined( $method ), "method is defined" );

# ===== TEST SECTION: Logic Parameter Addition =====
my $test = $method->add_logic_parameter(
    name => 'test_param',
    pattern => '^(.*)$',
    inequality_params => 1,
    regex_param => 1,
    not_param => 1,
    description => 'Test Parameter'
);

ok( $test, "add_logic_parameter()" );

# ===== TEST SECTION: Has Logic Parameter (not) =====
$method->{'input_params'}{'test_param_not'}{'is_set'} = 1;
$test = $method->has_logic_parameter( param => 'test_param', args => {} );
ok( $test, "has_logic_parameter()" );

# ===== TEST SECTION: Has Logic Parameter (not_like) =====
$method->{'input_params'}{'test_param_not'}{'is_set'} = 0;
$method->{'input_params'}{'test_param_not_like'}{'is_set'} = 1;
$test = $method->has_logic_parameter( param => 'test_param', args => {} );
ok( $test, "has_logic_parameter() with not_like" );

# ===== TEST SECTION: Default Values =====
is( $method->{'input_params'}{'offset'}{'default'}, 0, 'default offset 0' );
is( $method->{'input_params'}{'order_by'}{'default'}, 'test_order_by', 'default order_by' );
is( $method->{'input_params'}{'order'}{'default'}, 'DESC', 'default order' );

# ===== TEST SECTION: Input Validation and Acceptance =====
my $output_file;

# Test greater_equal parameter
open( FH, ">", \$output_file);
my $svc = GRNOC::WebService::Dispatcher->new(
    test_input => 'method=cds_test;test_param_greater_equal=555',
    output_handle => \*FH
);
$svc->register_method( $method );
$svc->handle_request();
my @input = split(/\n/, $output_file);
my $output = pop( @input );
my $results = JSON::XS::decode_json( $output );
my $result = $results->{'results'}[0]{'test_param'}[0];
is( $result, 555, "greater_equal input accepted" );
close( FH );

# Test regex parameter
open( FH, ">", \$output_file);
$svc = GRNOC::WebService::Dispatcher->new(
    test_input => 'method=cds_test;test_param_regex=^test.*$',
    output_handle => \*FH
);
$svc->register_method( $method );
$svc->handle_request();
@input = split(/\n/, $output_file);
$output = pop( @input );
$results = JSON::XS::decode_json( $output );
$result = $results->{'results'}[0]{'test_param'}[0];
is( $result, '^test.*$', "regex input accepted" );
close( FH );

# Test not_regex parameter
open( FH, ">", \$output_file);
$svc = GRNOC::WebService::Dispatcher->new(
    test_input => 'method=cds_test;test_param_not_regex=^foo.*$',
    output_handle => \*FH
);
$svc->register_method( $method );
$svc->handle_request();
@input = split(/\n/, $output_file);
$output = pop( @input );
$results = JSON::XS::decode_json( $output );
$result = $results->{'results'}[0]{'test_param'}[0];
is( $result, '^foo.*$', "not_regex input accepted" );
close( FH );

# Test inequality parameter validation (error case)
open( FH, ">", \$output_file);
$svc = GRNOC::WebService::Dispatcher->new(
    test_input => 'method=cds_test;test_param_greater_equal=NaN',
    output_handle => \*FH
);
$svc->register_method( $method );
$svc->handle_request();
@input = split(/\n/, $output_file);
$output = pop( @input );
$results = JSON::XS::decode_json( $output );
is( $results->{'error_text'}, 'cds_test: Parameter test_param_greater_equal only accepts positive integers and 0.', 'inequality enforce positive integer' );
close( FH );
