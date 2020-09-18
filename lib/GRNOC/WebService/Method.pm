#--------------------------------------------------------------------
#----- Copyright(C) 2013 The Trustees of Indiana University
#--------------------------------------------------------------------
#-----
#----- object oriented backend web service interface for core data services
#-----
#---------------------------------------------------------------------
use warnings;
use strict;

use GRNOC::WebService::Regex;
use Carp qw( longmess cluck );
use Data::Dumper;
use CGI;
use JSON::XS;
use Clone;
use Encode;
use GRNOC::Config;
use bytes;

package GRNOC::WebService::Method;

=head1 NAME

GRNOC::WebService::Method - GRNOC centric web service method object

Used to embody associate a registered method with its input params,
callback, documentation, etc.

=head1 SYNOPSIS

This module provides web service programers a method to represent a web service method which then
is registered with GRNOC::WebService.

  use GRNOC::WebService::Method;


  my $echo_method = GRNOC::WebService::Method->new(
    name            =>  "number_echo",
    description     =>  "this is a routine that will only echo a number"
    expires         =>  "-1d",
    output_type     =>  "application/json",
    callback        =>  \&num_echo,
    streaming       =>  1,
    output_formater =>  \&objToJson,
    );

  $echo_method->add_input_parameter(
    name    => "number",
    pattern   => "^(\d+)$",
    required  =>  1,
    multiple  =>  0,
    description => "integer that will be echoed back to you",
    default   => 13,
          );

  sub even_numbers_only {

    my ( $method, $input ) = @_;

    return $input % 2 == 0;
  }

  $echo_method->add_input_validator( name => 'even_numbers_only',
                                     description => 'This input validator will validate even numbers only.',
                                     callback => \&even_numbers_only,
                                     input_parameter => 'number' );

=head1 Callback Behavior

Callbacks are passed a reference to the method object and a reference to an input structure.

When an error occurs, the callback should use the Method->set_error() method to document the
error condition and then return undefined.

If conditions occur in which setting an error is too much, but an issue needs to be reported to the user,
the callback should use the Method->set_warning() method to document the warning condition.  However, as long
as an error does not appear, the callback should still return results (if any)

The second argument to a callback is reference to the untainted parameter hash, if the input parameter
is named "number"  then $params->{'number'}{'value'} will provide the value for that parameter.

A callback might look like this:

  sub number_echo{

        my $m_ref       = shift;
        my $params      = shift;

        my %results;
        my $num = $params->{'number'}{'value'};

        if($num > 1024){
                $m_ref->set_error(Carp::longmess("number value is > max value 1024"));
                return undef;
        }

        if ($num >=1024 && $num >=950) {
            $m_ref->set_error("Warning: Approaching max value of 1024.");
        }

        $results{'text'} = "input number: $num";

        #--- as number is the only input parameter, lets make sure others dont get past.
        return \%results;
  }


=head1 FUNCTIONS

=head2 new()

Constructor that takes the following parameters:

=over

=item name

the method name as make network accessible,  can not be help.  must be used chars and _ only.

=cut

=item is_default

if set to 1, when the webservice is called with no method, this method is called.

=cut

=item description

textual description of methods purpose

=cut

=item expires

defines the expires header directive, usefull for controlling caching

=cut

=item callback

the internal method called when this method is accessed.

=cut

=item output_formatter

function called to process ouput, it is assumed that you are passing a references to a multidimensioned struct

=cut

=back

=cut

sub new{
  my $that  = shift;
  my $class =ref($that) || $that;

  my %valid_parameter_list = (
                              'expires' => 1,
                              'output_type' => 1,
                              'output_formatter' => 1,
                              'name' => 1,
                              'callback' => 1,
                              'description' => 1,
                              'attachment' => 1,
                              'is_default' => 1,
                              'debug' => 1,
                              'streaming' => 1,
                              'xdr_regexp' => 1,
                              'config_file' => 1,
                              'enable_pattern_introspection' => 1,
                             );

  #--- overide the defaults
  my %args = (
              expires           => "-1d",
              output_type   => "application/json",
              output_formatter => sub { JSON::XS->new()->encode( shift ) },
              name      => undef,
              callback    => undef,
              description   => undef,
              attachment    => undef,
              debug                   => 0,
              streaming               => 0,
              xdr_regexp => 'grnoc.iu.edu$',
              config_file => '/etc/grnoc/webservice/config.xml',
              enable_pattern_introspection => 1,
              @_,
             );


  my $self = \%args;

  bless $self,$class;

  # validate the parameter list

  # only valid parameters
  foreach my $passed_param (keys %$self) {
    if (!(exists $valid_parameter_list{$passed_param})) {
      Carp::confess("invalid parameter [$passed_param]");
      return;
    }
  }
  # missing required parameters
  if (!defined $self->{'name'}) {
    Carp::confess("methods need a name");
    return;
  }
  if (!defined $self->{'description'}) {
    Carp::confess("methods need a description");
    return;
  }
  if (!defined $self->{'callback'}) {
    Carp::confess("need to define a proper callback");
    return;
  }
  
  #read config file and set enable_pattern_introspection
  my $config_file = $self->{'config_file'};
  if(-e $config_file){
      my $config = GRNOC::Config->new(config_file => $config_file);
      my $pattern_introspection = $config->get("/config/enable_pattern_introspection");

      $self->{enable_pattern_introspection} = $pattern_introspection->[0] if(defined($pattern_introspection) and defined($pattern_introspection->[0]));
  }

  return $self;

}

=head2 get_name()

returns the registerd method name for this method object.

=cut

sub get_name{
  my $self  = shift;
  return $self->{'name'};
}


=head2 add_input_parameter()

adds a new parameter to this method. Attributes include:

=over

=item name

parameter name

=cut

=item description

textual description of purpose

=cut

=item pattern

regexp used to untaint this parameter
default value is '^(\d+)$'

=cut

=item required

flag that indicates if this option is required. If not
provided required=1 is default

=cut

=item multiple

flag that indicates if this option can have multiple values
when this is set the parameter structure contains an array reference.
multiple=0 is the default.

=cut


=item default

allows for a default value to be used in case
where input not provided by client

=cut

=item ignore_default_input_validators

if set to 1, any default input validator subroutines given to the dispatcher will not be used for this input parameter.

=cut

=back

=cut



sub add_input_parameter{
  my $self = shift;
  #--- overwrite the defaults
  my %args = (
              pattern   => '^(\d+)$',
              required  => 1,
              multiple  => 0,
              ignore_default_input_validators => 0,
              input_validators => [],
              min_length => undef,
              max_length => undef,
              validation_error_text => undef,
              @_,
             );

  if (!exists $args{'allow_null'}) {
      if ($args{'required'}) {
          $args{'allow_null'} = 0;
      }
      else {
          $args{'allow_null'} = 1;
      }
  }

  if (!defined $args{'name'}) {
    Carp::confess("name is a required parameter");
    return;
  }

  if (!defined $args{'description'}) {
    Carp::confess("description is a required parameter");
    return;
  }

  if (!defined $args{'validation_error_text'}){
      my $error_text;
      my $pattern = $args{'pattern'};
      my $name    = $args{'name'};

      if ($pattern eq $GRNOC::WebService::Regex::NUMBER_ID){
          $error_text = "Parameter $name only accepts positive integers and 0.";
      }
      elsif ($pattern eq $GRNOC::WebService::Regex::BOOLEAN) {
	  $error_text = "Parameter $name only accepts either 0 or 1 for false or true values, respectively.";
      }
      elsif ($pattern eq $GRNOC::WebService::Regex::FLOAT){
          $error_text = "Parameter $name only accepts floating point numbers.";
      }
      elsif ($pattern eq $GRNOC::WebService::Regex::INTEGER){
          $error_text = "Parameter $name only accepts integer numbers.";
      }
      elsif ($pattern eq $GRNOC::WebService::Regex::ANY_NUMBER){
          $error_text = "Parameter $name only accepts numbers.";
      }
      elsif ($pattern eq $GRNOC::WebService::Regex::NAME_ID){
          $error_text = "Parameter $name only accepts printable characters. This excludes control characters like newlines, carrier return, and others.";
      }
      elsif ($pattern eq $GRNOC::WebService::Regex::TEXT){
          $error_text = "Parameter $name only accepts printable characters and spaces, including newlines. This excludes control characters.";
      }
      elsif ($pattern eq $GRNOC::WebService::Regex::IP_ADDRESS){
          $error_text = "Parameter $name only accepts valid IPv4 or IPv6 addresses, including valid shortened notation.";
      }
      elsif ($pattern eq $GRNOC::WebService::Regex::MAC_ADDRESS){
          $error_text = "Parameter $name only accepts valid MAC addresses using either a : or a - as delimiter.";
      }
      elsif ($pattern eq $GRNOC::WebService::Regex::HOSTNAME){
	  $error_text = "Parameter $name only accepts valid RFC1123 host/domain names.";
      }
      else {
          if($self->{'enable_pattern_introspection'} == 1){
              $error_text = "CGI input parameter $name does not match pattern /$pattern/";
          }
          else{
              $error_text = "CGI input parameter $name does not match pattern";
          }
      }

      $args{'validation_error_text'} = $error_text;
  }


  $self->{'input_params'}{$args{'name'}} = \%args;

  return 1;
}

=head2 remove_input_parameter()

removes a input parameter from this method.

=cut

sub remove_input_parameter{
  my $self  = shift;
  my $param = shift;

  if (defined $self->{'input_params'}{$param}) {
    delete $self->{'input_params'}{$param};
    return 1;
  }

  return;
}

=head2 add_input_validator()

This method takes a name, description, subroutine callback, and the name of an input parameter as arguments.  This
subroutine should return either a true or false value which states whether or not the supplied input to a particular
parameter is sane (true) or tainted (false).  An error will be returned unless every input supplied to the parameter
returns a true value when executed with every input validator supplied.  All default input validators defined in the
dispatcher must also return a true value, unless they are overridden with the ignore_default_input_validators => 1
argument in the add_input_parameter() method.

=cut

sub add_input_validator {

  my ( $self, %args ) = @_;

  my $name = $args{'name'};
  my $description = $args{'description'};
  my $callback = $args{'callback'};
  my $input_parameter = $args{'input_parameter'};

  my $input_validators = $self->{'input_params'}{$input_parameter}{'input_validators'};

  my $validator = {'name' => $name,
                   'description' => $description,
                   'callback' => $callback};

  push( @$input_validators, $validator );
}

=head2 help()

returns helpful info about this method

=cut

sub help {

  my $self = shift;

  my %help;

  $help{'name'}     = $self->{'name'};
  $help{'description'}  = $self->{'description'};
  $help{'expires'}  = $self->{'expires'};
  $help{'output_type'}  = $self->{'output_type'};

  # delete all the default input validator callbacks from the help output
  my $default_input_validators = Clone::clone( $self->{'dispatcher'}{'default_input_validators'} );

  foreach my $default_input_validator ( @$default_input_validators ) {

    delete( $default_input_validator->{'callback'} );
  }

  $help{'default_input_validators'} = $default_input_validators;

  # make a copy of input params so we dont destroy internal data
  my $input_params = Clone::clone( $self->{'input_params'} );

  # delete all the input validator callbacks from the help output
  my @input_param_names = keys( %$input_params );

  foreach my $input_param_name ( @input_param_names ) {

    if($self->{'enable_pattern_introspection'} == 0){
        delete ( $input_params->{$input_param_name}{'pattern'} );
    }    

    my $input_validators = $input_params->{$input_param_name}{'input_validators'};

    foreach my $input_validator ( @$input_validators ) {

      delete( $input_validator->{'callback'} );
    }
  }

  $help{'input_params'} = $input_params;

  return \%help;
}

=head2 get_warning()
gets the warnings encountered or undef.
=cut

sub get_warning {
    my $self = shift;
    return $self->{'warning'};
}


=head2 set_warning

taking a warning string as an argument, this goes
and either sets the warning if it's undefined,
or 

=cut

sub set_warning {
  my $self        = shift;
  my $warning       = shift;

  return if !$warning;

  if (!$self->{'warning'}) {
      $self->{'warning'} = [];
  }

  if (ref($warning) eq 'ARRAY') {
        push(@{$self->{'warning'}}, @$warning);
  }
  else {
    push (@{$self->{'warning'}}, $warning);
  }

    return join('\n', @{$self->{'warning'}});
}

=head2 get_error()

gets the last error encountered or undef.

=cut

sub get_error{
  my $self        = shift;
  return $self->{'error'};
}


=head2 set_error()

method which sets a new error and prints it to stderr
Can also be used by callback to signal error to client.

=cut

sub set_error{
  my $self        = shift;
  my $error       = shift;

  #$self->{'error'} = Carp::longmess("$0 $error");
  $self->{'error'}  = $error;
}

=head2 get_dispatcher()

gets the associated Dispatcher reference

=cut

sub get_dispatcher{
  my $self        = shift;
  return $self->{'dispatcher'};
}


=head2 set_dispatcher()

Sets the dispatcher reference

=cut

sub set_dispatcher{
  my $self             = shift;
  my $dispatcher       = shift;

  $self->{'dispatcher'} = $dispatcher;
}

=head2 parse_input_parameters()

protected method for parsing web service input

=cut

#----- this this called by the constructor and uses supplied attribute value
#----- pairs to automatically untaint each specified parameter.  Will incidate error
#----- if a parameter is missing or is present but malformed.
sub _parse_input_parameters {

  my ( $self, $cgi, $default_input_validators ) = @_;

  my $multipart = 0;

  foreach my $param (sort keys(%{$self->{'input_params'}})) {

    my $pattern                         = $self->{'input_params'}{$param}{'pattern'};
    my $required                        = $self->{'input_params'}{$param}{'required'};
    my $multiple                        = $self->{'input_params'}{$param}{'multiple'};
    my $default                         = $self->{'input_params'}{$param}{'default'};
    my $ignore_default_input_validators = $self->{'input_params'}{$param}{'ignore_default_input_validators'};
    my $input_validators                = $self->{'input_params'}{$param}{'input_validators'};
    my $min_length                      = $self->{'input_params'}{$param}{'min_length'};
    my $max_length                      = $self->{'input_params'}{$param}{'max_length'};
    my $allow_null                      = $self->{'input_params'}{$param}{'allow_null'};
    my $attachment                      = $self->{'input_params'}{$param}{'attachment'};
    my $validation_error_text           = $self->{'input_params'}{$param}{'validation_error_text'};

    my $mime_type = $cgi->content_type;
    if (defined $mime_type && lc($mime_type) =~ /multipart\/form-data/) {
      $multipart = 1;
    }

    my @input_array = $cgi->param($param);
    my $input_cnt = scalar @input_array;

    if ($input_cnt == 0) {
      #--- if input is not defined then set the input equal
      #--- to the default for this parameter

      if (ref($default) eq "ARRAY") {

        @input_array = @$default;
      }

      else {

        $input_array[0] = $default;
      }
    }

    # clear out existing array, if any, to avoid infinitely growing arrays in a mod_perl environment
    undef($self->{'input_params'}{$param}{'value'});
    $self->{'input_params'}{$param}{'is_set'} = 0;

    # perform the proper input validation on every supplied argument to this parameter
    foreach my $input (@input_array) {

      # ISSUE=8595 strip all leading and trailing whitespace if not attachment
      $input =~ s/^\s+|\s+$//g if ( defined( $input ) && !$attachment );

      # value not supplied for parameter
      if ( !defined( $input ) ) {

        # it was a required parameter
        if ( $required ) {

          $self->set_error( $self->{'name'}.": required input parameter $param is missing " );
          return undef;
        }
      }

      # value was given for parameter
      else {

        $self->{'input_params'}{$param}{'is_set'} = 1;

        # handle NULL parameters
        if ( $input eq "" ) {
           if ( !$allow_null ) {
             $self->set_error( $self->{'name'}.": input parameter $param cannot be NULL " );
             return undef;
           }

          if ( $multiple ) {
            push( @{$self->{'input_params'}{$param}{'value'}}, undef );
          }
          else {
            $self->{'input_params'}{$param}{'value'} = undef;
          }
        }

        #--- parameter exists
        elsif ( $input eq "" || # dont pattern match on a NULL value
                ( !$attachment && Encode::decode( 'UTF-8', $input ) =~ /$pattern/ ) || # if its not an attachment, decode UTF-8 first
                ( $attachment && $input =~ /$pattern/ ) ) { # its an attachment, do not decode UTF-8

	  my $input_value = $1;
          my $filename = undef;
          my $mime_type = undef;

          # re-encode back to UTF-8 if not an attachment
	  $input_value = Encode::encode( 'UTF-8', $input_value ) if ( !$attachment );

          if (defined($min_length) && length($input) < $min_length) {
                $self->set_error( $self->{'name'} . ": CGI input parameter $param is shorter than the specified minimum length of $min_length." );
                return undef;
          }
          if (defined($max_length) && length($input) > $max_length) {
                $self->set_error( $self->{'name'} . ": CGI input parameter $param is longer than the specified maximum length of $max_length." );
                return undef;
          }

          # make sure this input parameter validates against every default input validator subroutine
          if ( !$ignore_default_input_validators ) {

            foreach my $default_input_validator ( @$default_input_validators ) {

              my $callback = $default_input_validator->{'callback'};

              # execute the input validator subroutine, passing in the inputs to this parameter
              my $is_valid = &$callback( $self, $input );

              if ( !$is_valid ) {

                $self->set_error( $self->{'name'} . ": CGI input parameter $param does not pass default input validators." );
                return undef;
              }
            }
          }

          # make sure this input parameter validates any specific input validators
          foreach my $input_validator ( @$input_validators ) {

            my $callback = $input_validator->{'callback'};

            my $is_valid = &$callback( $self, $input );

            if ( !$is_valid ) {

              $self->set_error( $self->{'name'} . ": CGI input parameter $param does not pass input validators." );
              return undef;
            }
          }

          if ($multipart) {
            my $upload_data = $cgi->uploadInfo($input);
            if ($upload_data) {
              my $disposition = $upload_data->{'Content-Disposition'};
              $mime_type = $upload_data->{'Content-Type'};

              $disposition =~ /filename\=\"(.*)\"/;
              $filename = $1;

              $input_value = $input;
            }
          }

          if ($multiple) {	      

            push(@{$self->{'input_params'}{$param}{'value'}},$input_value);

            if ($multipart && $filename) {
              push(@{$self->{'input_params'}{$param}{'filename'}}, $filename);
              push(@{$self->{'input_params'}{$param}{'mime_type'}}, $mime_type);
            }
          }
          else {
            $self->{'input_params'}{$param}{'value'} = $input_value;
            if ($multipart && $filename) {
              $self->{'input_params'}{$param}{'filename'} = $filename;
              $self->{'input_params'}{$param}{'mime_type'} = $mime_type;
            }
          }

          if ($self->{'debug'}) {
            warn "- setting $param == $input_value\n";
          }
        }
        else {

          $self->set_error($self->{'name'} . ': ' . $validation_error_text);
          return undef;

        }

      }
    }

  }
  return 1;
}

=head2 get_value( PARAM )

 returns the value of the given input parameter name

=cut

sub get_value {

  my ( $self, $param ) = @_;

  return $self->{'input_params'}{$param}{'value'};
}

=head2 get_input_parameters( )

 returns the full set of input parameters

=cut


sub get_input_parameters {
    my $self = shift;

    return ($self->{'input_params'});
}


=head2 defined_param( PARAM )

 returns a true value if a parameter was given an input, returns false otherwise

=cut

sub defined_param {

  my ( $self, $param ) = @_;

  return $self->{'input_params'}{$param}{'is_set'};
}

=head2 get_headers()

Returns an array of explicitly set additional headers for this method. 

=cut

sub get_headers {
    my $self = shift;
    return $self->{'headers'};
}


=head2 set_headers()

Sets the internal explicit headers. This should be an array of objects each with
a name and a value field.

=cut

sub set_headers {
    my $self    = shift;
    my $headers = shift;
    $self->{'headers'} = $headers;
}



=head2 add_logic_parameter()

Requires the name, pattern, and description arguments, and creates 5 input parameters
(via calls to add_input_parameter() ).  The four additonal ones are for the '_not', '_like',
'_not_like', and 'logic' input parameters.  It will support multiple arguments, and it is
not a required parameter.  If the argument inequality is passed with a true value, it will
also add the four inequality input parameters for less than, greater than, etc.

=cut


sub add_logic_parameter {

  my ($self, %args) = @_;

  my $name = $args{'name'};
  my $pattern = $args{'pattern'};
  my $description = $args{'description'};
  my $like_param = $args{'like_param'};
  my $not_param = $args{'not_param'};
  my $inequality_params = $args{'inequality_params'};

  # add the main argument
  $self->add_input_parameter( name => $name,
                              pattern => $pattern,
                              required => 0,
                              multiple => 1,
                              description => $description );

  # add the corresponding not argument (if needed)
  if (!defined($not_param) || $not_param) {

    $self->add_input_parameter( name => $name . '_not',
                                pattern => $pattern,
                                required => 0,
                                multiple => 1,
                                description => "Uses NOT logic on the $name parameter." );
  }

  # add the corresponding like argument
  if (!defined($like_param) || $like_param) {

    $self->add_input_parameter( name => $name . '_like',
                                pattern => $GRNOC::WebService::Regex::NAME_ID,
                                required => 0,
                                multiple => 1,
                                description => "Uses RLIKE logic on the $name parameter." );
  }

  # add the corresponding not_like argument
  if ((!defined($not_param) || $not_param) && (!defined($like_param) || $like_param)) {

    $self->add_input_parameter( name => $name . '_not_like',
                                pattern => $GRNOC::WebService::Regex::NAME_ID,
                                required => 0,
                                multiple => 1,
                                description => "Uses NOT RLIKE logic on the $name parameter." );
  }

  # add the corresponding inequality arguments
  if ( $inequality_params ) {

    $self->add_input_parameter( name => $name . "_less",
                                pattern => $GRNOC::WebService::Regex::NUMBER_ID,
                                required => 0,
                                multiple => 1,
                                description => "Uses < logic on the $name parameter.");

    $self->add_input_parameter( name => $name . "_less_equal",
                                pattern => $GRNOC::WebService::Regex::NUMBER_ID,
                                required => 0,
                                multiple => 1,
                                description => "Uses <= logic on the $name parameter.");

    $self->add_input_parameter( name => $name . "_greater",
                                pattern => $GRNOC::WebService::Regex::NUMBER_ID,
                                required => 0,
                                multiple => 1,
                                description => "Uses > logic on the $name parameter.");

    $self->add_input_parameter( name => $name . "_greater_equal",
                                pattern => $GRNOC::WebService::Regex::NUMBER_ID,
                                required => 0,
                                multiple => 1,
                                description => "Uses >= logic on the $name parameter.");
  }

  # add the corresponding logic argument
  $self->add_input_parameter( name => $name . '_logic',
                              pattern => '^(AND|OR)$',
                              default => 'OR',
                              description => "Apply AND logic or OR logic if multiple $name options are specified." );
}


=head2 has_logic_parameter()

Requires the param and args arguments to be provided.  Returns a true value if either the
'param' or 'param_not' parameters were given in the callback.  The args parameter should
be passed from the method callback as is.

=cut



sub has_logic_parameter {

  my ( $self, %args ) = @_;

  my $param = $args{'param'};
  my $args = $args{'args'};

  return 1 if ( $self->defined_param( $param ) ||
                $self->defined_param( $param . "_not" ) ||
                $self->defined_param( $param . "_like" ) ||
                $self->defined_param( $param . "_not_like" ) ||
                $self->defined_param( $param . "_less" ) ||
                $self->defined_param( $param . "_less_equal" ) ||
                $self->defined_param( $param . "_greater" ) ||
                $self->defined_param( $param . "_greater_equal" ) );

  return 0;
}



=head2 parse_logic_parameter()

This is a helper method that returns a proper where clause to supply to the SQL::Abstract
style of queries in GRNOC::DatabaseQuery.  It requires the param, field, and args
parameters.  The param is the input parameter name, the field is the SQL column to query
on, and the args parameter is the one used in the callback method.  The having and dbh
parameters are optional, and should be given if the SQL column was created using the
GROUP_CONCAT operation.  The having parameter should be a true value in this case, and
the dbh parameter should be given the internal dbh object from GRNOC::DatabaseQuery.

=cut

sub parse_logic_parameter {

  my ($self, %args) = @_;

  my $param = $args{'param'};
  my $field = $args{'field'};
  my $args = $args{'args'};
  my $having = $args{'having'};
  my $dbh = $args{'dbh'};

  # if we need to use HAVING / FIND_IN_SET (for GROUP_CONCAT args)
  if ( $having ) {

    return _parse_logic_parameter_having( $args->{$param},
                                          $args->{$param . "_not"},
                                          $args->{$param . "_like"},
                                          $args->{$param . "_not_like"},
                                          $args->{$param . "_less"},
                                          $args->{$param . "_less_equal"},
                                          $args->{$param . "_greater"},
                                          $args->{$param . "_greater_equal"},
                                          $args->{$param . "_logic"},
                                          $field,
                                          $dbh );
  }

  else {

    my $res = _parse_logic_parameter( $args->{$param},
                                      $args->{$param . "_not"},
                                      $args->{$param . "_like"},
                                      $args->{$param . "_not_like"},
                                      $args->{$param . "_less"},
                                      $args->{$param . "_less_equal"},
                                      $args->{$param . "_greater"},
                                      $args->{$param . "_greater_equal"},
                                      $args->{$param . "_logic"},
                                      $field );

    return $res;
  }
}



### HERE BE DRAGONS ###
sub _parse_logic_parameter_having {

  my ( $main_param, $not_param, $like_param, $not_like_param, $less_param, $less_equal_param, $greater_param, $greater_equal_param, $logic_param, $field, $dbh ) = @_;

  my $having_sql = "( ";
  my $added_logic_param = 0;
  my $logic_param_value = $logic_param->{'value'};

  if ($main_param->{'is_set'}) {

    my $vals = $main_param->{'value'};

    for (my $i = 0; $i < @$vals; $i++) {

      my $param = $dbh->quote(@$vals[$i]);

      if ($i == 0) {

        $having_sql .= "FIND_IN_SET($param, $field) != 0";
        $added_logic_param++;
      }

      else {

        $having_sql .= " $logic_param_value FIND_IN_SET($param, $field) != 0";
      }
    }
  }

  if ($not_param->{'is_set'}) {

    my $vals = $not_param->{'value'};

    for (my $i = 0; $i < @$vals; $i++) {

      my $param = $dbh->quote(@$vals[$i]);

      if ($i == 0 && !$added_logic_param) {

        $having_sql .= "FIND_IN_SET($param, $field) = 0";
        $added_logic_param++;
      }

      else {

        $having_sql .= " $logic_param_value FIND_IN_SET($param, $field) = 0";
      }
    }
  }

  if ($like_param->{'is_set'}) {

    my $vals = $like_param->{'value'};

    for (my $i = 0; $i < @$vals; $i++) {

      my $param = $dbh->quote(",?" . @$vals[$i] . ",?");

      if ($i == 0 && !$added_logic_param) {

        $having_sql .= "$field RLIKE $param";
        $added_logic_param++;
      }

      else {

        $having_sql .= " $logic_param_value $field RLIKE $param";
      }
    }
  }

  if ($not_like_param->{'is_set'}) {

    my $vals = $not_like_param->{'value'};

    my $not_like_having_sql = "( ( ";

    for (my $i = 0; $i < @$vals; $i++) {

      my $param = $dbh->quote(",?" . @$vals[$i] . ",?");

      if ($i == 0) {

        $not_like_having_sql .= "$field NOT RLIKE $param";
      }

      else {

        $having_sql .= " $logic_param_value $field NOT RLIKE $param";
      }
    }

    $not_like_having_sql .= " ) OR $field IS NULL";

    if (!$added_logic_param) {

      $having_sql .= " $not_like_having_sql )";
    }

    else {

      $having_sql .= " $logic_param_value $not_like_having_sql )";
    }
  }

  $having_sql .= " )";

  return $having_sql;
}

sub _parse_logic_parameter {

  my ( $main_param, $not_param, $like_param, $not_like_param, $less_param, $less_equal_param, $greater_param, $greater_equal_param, $logic_param, $field ) = @_;

  my $result = [];
  my $logic_param_value = $logic_param->{'value'};

  if ($logic_param_value eq "AND") {

    $logic_param = "-and";
  }

  else {

    $logic_param = "-or";
  }

  my $added_logic_param = 0;

  # handle main equality params
  if ($main_param->{'is_set'}) {

    my $vals = $main_param->{'value'};

    for (my $i = 0; $i < @$vals; $i++) {

      my $arg = @$vals[$i];

      # handle NULLs
      if ( !defined( $arg ) ) {

        push( @$result, $field => undef );
      }

      else {

        push( @$result, $field => {'=', $arg} );
      }
    }
  }

  # handle not equality params
  if ($not_param->{'is_set'}) {

    my $vals = $not_param->{'value'};

    my $not_param_result = [];

    my $has_null = 0;

    for (my $i = 0; $i < @$vals; $i++) {

      my $arg = @$vals[$i];

      # handle NULL args
      if ( !defined( $arg ) ) {

        my $inn = "IS NOT NULL";

        $has_null++;

        push( @$not_param_result, $field => \$inn );
      }

      else {

        push( @$not_param_result, $field => {'!=', $arg} );
      }
    }

    if ( !$has_null ) {

      # include OR IS NULL if using !=
      push( @$result, [-or => [$logic_param => $not_param_result], [$field => undef]] );
    }

    else {

      push( @$result, [$logic_param => $not_param_result] );
    }
  }

  # handle like params
  if ($like_param->{'is_set'}) {

    my $vals = $like_param->{'value'};

    for (my $i = 0; $i < @$vals; $i++) {

      my $arg = @$vals[$i];

      push(@$result, $field => {'-rlike', $arg});
    }
  }

  # handle not like params
  if ($not_like_param->{'is_set'}) {

    my $vals = $not_like_param->{'value'};

    my $not_like_param_result = [];

    for (my $i = 0; $i < @$vals; $i++) {

      my $arg = @$vals[$i];

      push(@$not_like_param_result, $field => {'-not_rlike', $arg});
    }

    # include OR IS NULL if using NOT LIKE
    push(@$result, [-or => [$logic_param => $not_like_param_result], [$field => undef]])
  }

  # handle less params
  if ( $less_param->{'is_set'} ) {

    my $vals = $less_param->{'value'};

    for ( my $i = 0; $i < @$vals; $i++ ) {

      my $arg = @$vals[$i];

      push( @$result, $field => {'<', $arg} );
    }
  }

  # handle less_equal params
  if ( $less_equal_param->{'is_set'} ) {

    my $vals = $less_equal_param->{'value'};

    for ( my $i = 0; $i < @$vals; $i++ ) {

      my $arg = @$vals[$i];

      push( @$result, $field => {'<=', $arg} );
    }
  }

  # handle greater params
  if ( $greater_param->{'is_set'} ) {

    my $vals = $greater_param->{'value'};

    for ( my $i = 0; $i < @$vals; $i++ ) {

      my $arg = @$vals[$i];

      push( @$result, $field => {'>', $arg} );
    }
  }

  # handle greater_equal params
  if ( $greater_equal_param->{'is_set'} ) {

    my $vals = $greater_equal_param->{'value'};

    for ( my $i = 0; $i < @$vals; $i++ ) {

      my $arg = @$vals[$i];

      push( @$result, $field => {'>=', $arg} );
    }
  }

  return [$logic_param => $result];
}





=head2 _return_results()

 protected method for formatting callback results and setting httpd response headers

=cut


#----- formats results in JSON then sets proper cache directive header and off we go
sub _return_results{
    my $self     = shift;
    my $cgi      = shift;
    my $results  = shift;
    my $fh       = shift;
    
    if (!defined $fh) {
        Carp::Confess("input filehandle  not defined");
        return
    }
    
    my $allow_credentials='false';
    my $allowed_origin= "http://grnoc.iu.edu"; #this fails most of the time
    my $regexp=$self->{'xdr_regexp'};
    
    if ( defined( $cgi->http('ORIGIN') ) && defined( $regexp ) && $cgi->http('ORIGIN') =~ /$regexp/ ) {
        $allowed_origin=$cgi->http('ORIGIN');
        if (defined $ENV{'HTTPS'}) {
            $allow_credentials='true';
        }
    }
    
    my $explicit_headers = $self->get_headers();
    
    my $all_headers;
    my $answer;

    # If the method has explicitly set its own headers, use those.
    if ($explicit_headers){
        foreach my $header (@$explicit_headers){
            $all_headers->{$header->{'name'}} = $header->{'value'};
        }
    }
    # Set up our default headers
    else {
        $all_headers->{'type'}    = $self->{'output_type'};
        $all_headers->{'expires'} = $self->{'expires'};
        $all_headers->{'Access_Control_Allow_Origin'}      = $allowed_origin;
        $all_headers->{'Access_Control_Allow_Credentials'} = $allow_credentials;
        
        # Include attachment information if relevant. 
        if ($self->{'attachment'}){
            $all_headers->{'attachment'} = $self->{'attachment'};
        }
        # For non attachments, indicate that we're using utf-8
        else {
            $all_headers->{'charset'} = 'utf-8';
        }
    }

    # if the output isn't streaming, we can calcuate the full answer right now
    # along with its length
    if (! $self->{'streaming'}){
        $answer = $self->{'output_formatter'}($results);
        if (! $explicit_headers){
            if ($all_headers->{'type'} =~ /^(application|text)\//) {
                $all_headers->{'content_length'} = bytes:length($answer);
            }
            else {
                $all_headers->{'content_length'} = bytes:length($answer);
            }
        }
    }
    
    # print off our final computed headers
    print $fh $cgi->header($all_headers);

    # if it's streaming, the output formatter is responsible for actually outputing
    # into the filehandle, so we just pass it along
    if ($self->{'streaming'}){
        $self->{'output_formatter'}($results,$fh);
    }
    # if it's NOT streaming, we already have the answer so just print it to the handle
    else {
        print $fh $answer;
    }

}

=head2 _return_error()

 protected method for formatting callback results and setting httpd response headers

=cut


#----- formats results in JSON then seddts proper cache directive header and off we go
sub _return_error{
  my $self        = shift;
  my $cgi   = shift;
  my $fh          = shift;

  my %error;

  $error{"error"}   = 1;
  $error{'error_text'}  = $self->get_error();
  $error{'results'}   = undef;

  print $fh $cgi->header(-type=>'text/plain', -expires=>'-1d');

  #--- would be nice if client could pass a output format param and select between json and xml?
  print $fh  JSON::XS::encode_json(\%error);

}



=head2 handle_request()

 method called by dispatcher when a request comes in, passes
 a cgi object reference, a file handle, and a state reference.

=cut

sub handle_request {

  my ( $self, $cgi, $fh, $state, $default_input_validators ) = @_;

  my $res = $self->_parse_input_parameters( $cgi, $default_input_validators );
  if (!defined $res) {
    $self->_return_error($cgi,$fh);
    return;
  }

  #check for cors and options
  if (defined $ENV{'REQUEST_METHOD'} and ($ENV{'REQUEST_METHOD'} eq 'OPTIONS')) {
    #warn("got options");
    if (defined $cgi->http('ACCESS_CONTROL_REQUEST_METHOD') and (defined $cgi->http('ORIGIN'))) {

      #warn ("seems like a cors request");
      my $allow_credentials='false';
      my $allowed_origin= "http://grnoc.iu.edu"; #this fails most of the time
      my $regexp=$self->{'xdr_regexp'};
      if ( $cgi->http('ORIGIN') =~ /$regexp/) {

        $allowed_origin=$cgi->http('ORIGIN');
        if (defined $ENV{'HTTPS'}) {
          $allow_credentials='true';
        }
      }
      print $cgi->header(-Access_Control_Allow_Origin => $allowed_origin,
                         -Access_Control_Allow_Headers => 'X-Requested-With',
                         -Access_Control_Max_Age => 60 , #max-age is the caching of the preflight
                         -Access_Control_Allow_Credentials => $allow_credentials,
                        );
      return;
    }
  }



  #--- call the callback
  my $callback    = $self->{'callback'};
  my $results     =  &$callback($self,$self->{'input_params'},$state);

  if (!defined $results) {
    $self->_return_error($cgi,$fh);
    return;
  }
  else {
    #--- return results
    $self->_return_results($cgi,$results,$fh);
    return 1;
  }
}

1;
