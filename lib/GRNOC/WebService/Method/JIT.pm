#--------------------------------------------------------------------
#----- Copyright(C) 2011 The Trustees of Indiana University
#--------------------------------------------------------------------
#----- $LastChangedBy: $
#----- $LastChangedRevision: $
#----- $LastChangedDate: $
#----- $HeadURL: $
#----- $Id: $
#-----
#----- This class extends GRNOC::WebService::Method and adds its own
#----- default set of input parameters and helper methods to enable for 
#----- dynamic parameter registration.  
#----- 
#---------------------------------------------------------------------

=head1 NAME

GRNOC::WebService::Method::JIT - extended Method class for JIT method definitions

=head1 SYNOPSIS

This module extends the GRNOC::WebService::Method class to support the definition of method parameters at the time a method is called or help is called.




use GRNOC::WebService::Method::JIT;

my $static_parameters = [
                           {
                             name=> 'example_group_id',
                             description => 'The Group to look for the example in',
                             pattern => $NUMBER_ID,
                             required => 1,
                             multiple => 1,
                           },
                           {
                             name=> 'example_method_type',
                             description => 'The type of method we're giving in this example,
                             pattern => $TEXT,
                             required => 1,
                             multiple => 1,
                             add_logic_parameter => 1 # allows for the addition of logic parameters for a dynamic param, has same defaults as base Method's add_logic_parameter method.
                           }
                        ];

my $get_dynamic_parameters = sub {
  my $method_ref = shift;
  #will only have static parameters at this point
  my $params = shift;

  my $db = GRNOC::DatabaseQuery... #do dbq magic here

  #define $db->get_example_parameters ....

  my $results $db->get_example_parameters(group_id => $params->{'example_group_id'},
                                         method_type => $params->{'example_method_type'} );
  my $parameter_set = [];
  foreach my $new_param (@$results){
      push( @$parameter_set , {
                              name=> $new_param->{'name'},
                              description => $new_param->{'description'},
                              pattern => $new_param->{'pattern'},
                              required => $new_param->{'required'},
                              multiple => $new_param->{'multiple'},
                              });
  }

  return ($parameter_set);

};

my $method = GRNOC::WebService::Method::JIT->new( name             =>  "example_method",
                                                  description      =>  "CDS method example"
                                                  expires          =>  "-1d",
                                                  dynamic_input_parameter_callback => \&get_dynamic_parameters,
                                                  static_input_parameters => $static_parameters,
                                                  callback         =>  \&callback,
                                                 );




=head1 FUNCTIONS

=head2 new()

The constructor takes the same parameters as GRNOC::WebService::Method with the following additions


=over

=item static_parameters

set of parameter configurations, with the same options as GRNOC::WebService::Method takes add_input_parameter with 

=item dynamic_input_parameter_callback

the method to be called to determine what dynamic parameters to add. Will be passed the static parameters with values to determine what, if any parameters should be added to the method currently.


=item parameter_schema

all parameters passed either to static_parameters or returned by a dynamic_parameter_callback should follow the pattern below:

my $params = [
              {
                             name=> 'example_parameter',
                             description => 'The parameter_description',
                             pattern => $TEXT,
                             required => 1|0,
                             multiple => 1|0,
                             add_logic_parameter => 1 # allows for the addition of logic parameters for a dynamic param, has same defaults as base Method's add_logic_parameter method.
               },
              ]


=back

=cut

package GRNOC::WebService::Method::JIT;

use strict;
use warnings;

use base 'GRNOC::WebService::Method';

use GRNOC::WebService::Regex;
use Data::Dumper;

sub new {

  my $caller = shift;
  my $class = ref( $caller ) || $caller;

  my %args = @_;

  #don't send static_input parameters or dynamic callback to the base class
  my $static_input_parameters = delete $args{'static_input_parameters'};
  my $dynamic_input_callback  = delete $args{'dynamic_input_parameter_callback'};

  # call GRNOC::WebService::Method constructor
  my $self = $class->SUPER::new( %args );
  bless($self, $class);

  $self->{'static_input_parameters'} = $static_input_parameters;
  $self->{'dynamic_input_parameter_callback'} = $dynamic_input_callback;
  if (!defined $self->{'static_input_parameters'} ){
      Carp::confess("JIT Methods must have static parameters defined at instantiation");
      return;
  }

  #register static parameters that are required to determine other parameters
  foreach my $static_parameter (@{$self->{'static_parameters'} }) {
      my $result = $self->add_input_parameter($static_parameter);
      if (!$result){
          return;
      }
  }

  return $self;
}

=head2 help

  Overrides GRNOC::WebService::Method->help to set up dynamic parameters, any parameters that are required in static parameters will be required in help

=cut

sub help {
    my $self = shift;


    #ugly TODO make not suck, is this inside out?

    my $dispatcher = $self->get_dispatcher;
    my $cgi = $dispatcher->{'cgi'};
    my $default_input_validators = $dispatcher->{'default_input_validators'};
    #TODO get state data?
    my $state;
    #reinit parameters to include all required params for new hotness.
    $self->_reinitialize_parameters($cgi,$state,$default_input_validators);

    return $self->SUPER::help();
}

=head2 handle_request()

  Overrides GRNOC::WebService::handle_request() to dynamically register parameters before passing on to GRNOC::WebService::Method::handle_request()

=cut

sub handle_request {

    my ($self,$cgi,$fh,$state, $default_input_validators ) = @_;

    $self->_reinitialize_parameters($cgi,$state,$default_input_validators);

    return $self->SUPER::handle_request($cgi, $fh, $state, $default_input_validators );

}

sub _reinitialize_parameters {
    my $self = shift;
    my ($cgi,$state,$default_input_validators) = @_;

    my $static_parameters = $self->get_static_input_parameters;
    my $current_input_parameters = $self->get_input_parameters;
    my $dynamic_parameter_lookup = $self->{'dynamic_input_parameter_callback'};
    my %seen ;
    #kill all params and re-add static parameters
    foreach my $param (keys %$current_input_parameters) {
        $self->remove_input_parameter($param);
    }
    foreach my $static_parameter (@$static_parameters) {
        if ($static_parameter->{'add_logic_parameter'} ){
            $self->add_logic_parameter(%$static_parameter);
        }
        else{
            $self->add_input_parameter(%$static_parameter);
        }
        $seen{$static_parameter->{'name'}} =1;
    }
    #set input params for just static input parameters
    my $res = $self->_parse_input_parameters($cgi,$default_input_validators);

    my $new_params = &$dynamic_parameter_lookup($self,$self->{'input_params'},$state);

    unless ($new_params){
        return; #why don't we have any new params :/
    }
    #we could have duplicate parameter names, this could be bad but for now we will take the first one as correct
    foreach my $param (@$new_params){
        unless($seen{ $param->{'name'} }){
            if ($param->{'add_logic_parameter'} ){
                $self->add_logic_parameter(%$param);
            }
            else{
                $self->add_input_parameter(%$param);
            }
            $seen{$param->{'name'}} =1;
        }
    }
    #get values for all newly added parameters!
    $self->_parse_input_parameters($cgi,$default_input_validators);
    return 1;
}

=head2 get_static_input_parameters

returns the set of static_input_parameters currently defined

=cut

sub get_static_input_parameters {
    my $self= shift;

    return ($self->{'static_input_parameters'});

}



1;
