#--------------------------------------------------------------------
#----- Copyright(C) 2013 The Trustees of Indiana University
#--------------------------------------------------------------------
#----- $LastChangedBy: $
#----- $LastChangedRevision: $
#----- $LastChangedDate: $
#----- $HeadURL: $
#----- $Id: $
#-----
#----- This class extends GRNOC::WebService::Method and adds its own
#----- default set of input parameters and helper methods.  For
#----- example, the limit, offset, order_by, and order parameters are
#----- automatically created.  It also exposes an add_logic_parameter
#----- method, so if you were adding a logic parameter with the name
#----- 'foo', it will automatically create the 'foo_not' and
#----- 'foo_logic' input parameters.  You can optionally create more
#----- parameters for less than, greater than, less than or equal to,
#----- and greather than or equal to.
#---------------------------------------------------------------------

=head1 NAME

GRNOC::WebService::Method::CDS - extended Method class for CDS-style input parameters

=head1 SYNOPSIS

This module extends the GRNOC::WebService::Method class and automatically adds its own
set of input parameters and helper methods.  For example, the limit, offset, order_by,
and order parameters are automatically created.  It also handles logic parameters
which support the and & not parameters.  It requires that you specify a default
order_by parameter.

use GRNOC::WebService::Method::CDS;

my $method = GRNOC::WebService::Method::CDS->new( name             =>  "example_method",
                                                  description      =>  "CDS method example"
                                                  expires          =>  "-1d",
                                                  callback         =>  \&callback,
                                                  default_order_by => "name",
                                                  default_order    => 'DESC' );

# this will automatically create an example_not & example_logic parameter as well
$method->add_logic_parameter( name => 'example',
                              pattern => '^(.*)$',
                              required => 1,
                              description => 'Example parameter' );

sub callback {

  my ( $method, $args ) = @_;

  # parse the order / order_by params
  my $order_by = $method->parse_order_by( order => $args->{'order'}{'value'},
                                          order_by => $args->{'order_by'}{'value'} );

  $dbq->select( ...,
                order_by => $order_by );

  # ...
}

=head1 FUNCTIONS

=head2 new()

The constructor takes the same parameters as GRNOC::WebService::Method, but also requires
the default_order_by parameter to be specified, which determines which field(s) to sort by.

=head2 parse_order_by()

This is a helper method that returns a valid structure to give to the GRNOC::DatabaseQuery
object for its order_by parameter in the select() method.  It takes an order and order_by
argument, which should already exist in the callback function.

=cut



package GRNOC::WebService::Method::CDS;

use strict;
use warnings;

use base 'GRNOC::WebService::Method';

use GRNOC::WebService::Regex;
use Data::Dumper;

sub new {

  my $caller = shift;
  my $class = ref( $caller ) || $caller;

  my %args = @_;

  # dont feed the base class the default_order & default_order_by params
  my $default_order_by = $args{'default_order_by'};
  my $default_order = $args{'default_order'};

  delete( $args{'default_order_by'} );
  delete( $args{'default_order'} );

  # call GRNOC::WebService::Method constructor
  my $self = $class->SUPER::new( %args );

  # make sure they gave us default_order_by
  die( "default_order_by must be given" ) if ( !defined( $default_order_by ) );

  # use ASC if no default_order given
  $default_order = 'ASC' if ( !defined( $default_order ) );

  # make sure default_order is either ASC or DESC
  die( "default_order must be either ASC or DESC" ) if ( $default_order ne "ASC" && $default_order ne "DESC" );

  $self->add_input_parameter( name => 'limit',
                              pattern => $NUMBER_ID,
                              required => 0,
                              description => 'The limit of the number of results to return.' );

  # add the 'offset' input param to the get_circuits() method
  $self->add_input_parameter( name => 'offset',
                              pattern => $NUMBER_ID,
                              default => 0,
                              description => 'The offset of the results to return.' );

  # add the 'order_by' input param to the get_circuits() method
  $self->add_input_parameter( name => 'order_by',
                              pattern => $NAME_ID,
                              multiple => 1,
                              default => $default_order_by,
                              description => 'The field(s) by which to sort/order by.' );

  # add the 'order' input param to the get_circuits() method
  $self->add_input_parameter( name => 'order',
                              pattern => '^(ASC|DESC)$',
                              default => $default_order,
                              description => 'Specifies the order of results to be in either ascending or descending order.' );

  bless($self, $class);

  return $self;
}

sub parse_order_by {

  my ($self, %args) = @_;

  my $order = $args{'order'};
  my $order_by = $args{'order_by'};

  if ($order eq "ASC") {

    $order = "-asc";
  }

  else {

    $order = "-desc";
  }

  return [ {$order => $order_by} ];
}

1;
