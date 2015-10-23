use strict;
use warnings;

use Test::More tests => 9;

use GRNOC::WebService;
use GRNOC::WebService::Method::CDS;
use JSON::XS;
use Data::Dumper;

sub callback {

    my ( $method, $args ) = @_;

    return {'results' => [{'test_param' => $args->{'test_param_greater_equal'}{'value'}}]};
}

my $method = GRNOC::WebService::Method::CDS->new( name => 'cds_test',
                                                  description => "CDS test method",
                                                  expires => "-1d",
                                                  callback => \&callback,
                                                  default_order_by => 'test_order_by',
                                                  default_order => 'DESC' );

# make sure defined value is returned
ok( defined( $method ), "method is defined" );

my $test = $method->add_logic_parameter( name => 'test_param',
                                         pattern => '^(.*)$',
					 inequality_params => 1,
                                         description => 'Test Parameter' );

# make sure add_logic_parameter returns true value
ok( $test, "add_logic_parameter()" );

# simulate a not parameter being set
$method->{'input_params'}{'test_param_not'}{'is_set'} = 1;

$test = $method->has_logic_parameter( param => 'test_param',
                                      args => {} );

# make sure has_logic_parameter returns true for args given
ok( $test, "has_logic_parameter()" );

$method->{'input_params'}{'test_param_not'}{'is_set'} = 0;
$method->{'input_params'}{'test_param_not_like'}{'is_set'} = 1;

$test = $method->has_logic_parameter( param => 'test_param',
                                      args => {} );

# make sure has_logic_parameter returns true for args given
ok( $test, "has_logic_parameter() with not_like" );

# make sure default offset is 0
is( $method->{'input_params'}{'offset'}{'default'}, 0, 'default offset 0' );

# make sure default order_by is 'test_order_by'
is( $method->{'input_params'}{'order_by'}{'default'}, 'test_order_by', 'default order_by' );

# ISSUE=7082 make sure default order is DESC
is( $method->{'input_params'}{'order'}{'default'}, 'DESC', 'default order' );

# ISSUE=9534 make sure inequality params only accept positive integers

my $output_file;
open( FH, ">", \$output_file);

my $svc = GRNOC::WebService::Dispatcher->new( test_input => 'method=cds_test;test_param_greater_equal=555',
                                              output_handle => \*FH );

$svc->register_method( $method );

$svc->handle_request();

my @input = split(/\n/, $output_file);
my $output = pop( @input );

my $results = JSON::XS::decode_json( $output );
my $result = $results->{'results'}[0]{'test_param'}[0];

is( $result, 555, "greater_equal" );

close( FH );

open( FH, ">", \$output_file);

$svc = GRNOC::WebService::Dispatcher->new( test_input => 'method=cds_test;test_param_greater_equal=NaN',
					   output_handle => \*FH );

$svc->register_method( $method );

$svc->handle_request();

@input = split(/\n/, $output_file);
$output = pop( @input );
$results = JSON::XS::decode_json( $output );

is( $results->{'error_text'}, 'cds_test: Parameter test_param_greater_equal only accepts positive integers and 0.', 'inequality enforce positive integer' );
