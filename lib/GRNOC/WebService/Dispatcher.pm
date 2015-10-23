#--------------------------------------------------------------------
#----- Copyright(C) 2013 The Trustees of Indiana University
#--------------------------------------------------------------------
#----- $LastChangedBy: daldoyle $
#----- $LastChangedRevision: 28537 $
#----- $LastChangedDate: 2014-01-17 15:26:10 +0000 (Fri, 17 Jan 2014) $
#----- $HeadURL: svn+ssh://svn.grnoc.iu.edu/grnoc/perl-lib/GRNOC-WebService/trunk/lib/GRNOC/WebService/Dispatcher.pm $
#----- $Id: Dispatcher.pm 28537 2014-01-17 15:26:10Z daldoyle $
#-----
#----- object oriented backend web service interface for core data services
#-----
#---------------------------------------------------------------------
use CGI;
use warnings;
use strict;

package GRNOC::WebService::Dispatcher;

use Data::Dumper;
use JSON::XS;

=head1 NAME

GRNOC::WebService::Dispatcher - GRNOC centric web service dispatcher

=head1 SYNOPSIS

This module provides web service programers an abstracted JSON/CGI web service base object.
The object handles the task of input parameter processing and output formatting. It also takes
care of setting up the HTTP response headers including expires header.

Perhaps a little code snippet.

  use GRNOC::WebService::Dispatcher;
  use GRNOC::WebService::Method;


  my $echo_method = GRNOC::WebService::Method(
                                                name            =>  "number_echo",
                                                description     =>  "this is a routine that will only echo a number"
                                                expires         =>  "-1d",
                                                output_type     =>  "application/json",
                                                callback        =>  \&num_echo,
                                                output_formater =>  \&ObjToJSON,
                                            );

  $echo_method->add_input_parameter(
                                                name            => "number",
                                                pattern         => "^(\d+)$",
                                                required        =  1,
                                                description     = "integer that will be echoed back to you",
                                        );




  my $svc = GRNOC::WebService::Dispatcher->new();

  $svc->add_default_input_validator( name => 'allow_everything',
                                     description => 'This input validator will allow any input.',
                                     callback => sub { my ( $method, $input ) = @_; return 1; } );

  $svc->register_method($echo_method);

  $svc->handle_request();




=cut


=head1 FUNCTIONS


=head2 new()

Object constructor.  There are two optional input parameters, test_input and allowed_proxy_users.

test_input is used to pass a set of test input cgi parameters so we can
perform unit testing, etc. "foo=bar&baz=666" might be an example input

allowed_proxy_users is an array of usernames that are allowed to perform proxy requests

=cut


=head2 help()

returns list of avail methods or if parameter 'method_name' provided, the details about that method

=cut
sub help{
  my $m_ref   = shift;
  my $params  = shift;

  my %results;

  my $method_name = $params->{'method_name'}{'value'};
  my $dispatcher = $m_ref->get_dispatcher();

  if (!defined $method_name) {
    return $dispatcher->get_method_list();
  }
  else {
    my $help_method = $dispatcher->get_method($method_name);
    if (defined $help_method) {
      return $help_method->help();
    }
    else {
      $m_ref->set_error("unknown method: $method_name\n");
      return undef;
    }
  }

}

=head2 _return_error()

 protected method for formatting callback results and setting httpd response headers

=cut


#----- formats results in JSON then seddts proper cache directive header and off we go
sub _return_error{
  my $self        = shift;

  my $cgi         = $self->{'cgi'};
  my $fh          = $self->{'output_handle'};

  my %error;

  $error{"error"} = 1;
  $error{'error_text'} = $self->get_error();
  $error{'results'} = undef;

  print $fh $cgi->header(-type=>'text/plain', -expires=>'-1d');

  #--- would be nice if client could pass a output format param and select between json and xml?
  print $fh  JSON::XS::encode_json(\%error);

}




=head2 new()

constructor

=cut
sub new{
  my $that  = shift;
  my $class =ref($that) || $that;

  my %args = (
              debug                => 0,
              allowed_proxy_users  => [],
              max_post_size        => 0,
              default_input_validators => [],
              @_,
             );

  my $self = \%args;

  if (!defined $self->{'ouput_type'}) {
    $self->{'output_type'} = "application/json";
  }

  #--- check for alternate output handle
  if (!defined $self->{'output_handle'}) {
    $self->{'output_handle'} = \*STDOUT;
  }


  #--- register builtin help method
  bless $self,$class;

  #--- register the help method
  my $help_method = GRNOC::WebService::Method->new(
                                                   name   => "help",
                                                   description  => "provide intropective documentation about registered methods",
                                                   is_default      => 1,
                                                   callback => \&help,
                                                  );
  $help_method->add_input_parameter(
                                    name            => "method_name",
                                    pattern         => '^((\w+|\_)+)$',
                                    required        =>  0,
                                    description     => "optional method name, if provided will give details about this specific method",
                                   );

  $self->register_method($help_method);


  return $self;

}



=head2 handle_request($state_ref)

after initialization, this method hands control over to the
service object where it will wait for input and then begin processing
if proper input provided, then the object will call the proper callback.

The state ref is an optional parameter that allows the caller to send
explicit state data do the method.

=cut

sub handle_request{
  my $self  = shift;
  my $state       = shift;
  my $method;

  #--- set a max POST size, if necessary (this needs to come before we create a CGI object)
  if (defined $self->{'max_post_size'} && ($self->{'max_post_size'} > 0)) {
    $CGI::POST_MAX = $self->{'max_post_size'};
  }

  # create CGI obj if for some reason we haven't already
  #--- check for test input
  if (defined $self->{'test_input'}) {

    $self->{'cgi'} = new CGI($self->{'test_input'});
  }
  else {
    $self->{'cgi'} = new CGI;
  }

  #--- check for an error
  my $cgi_err = $self->{'cgi'}->cgi_error;
  if ($cgi_err) {
    $self->_set_error($cgi_err);
    $self->_return_error();
    return undef;
  }

  #--- each service implementation can have several methods
  if (!defined $self->{'cgi'}->param('method')) {

    if (!defined $self->{'default_method'}) {
      $self->_set_error("no method specified");
      $self->_return_error();
      return undef;
    }
    else {
      $self->{'cgi'}->param(-name=>'method',-value=> $self->{'default_method'});
    }

  }

  $self->{'cgi'}->param('method') =~ /^(\w+)$/;
  $method = $1;

  #--- check for properly formed method
  if (!defined $method) {
    $self->_set_error("format error with method name");
    $self->_return_error();
    return undef
  }

  #--- check for method being defined
  if (!defined $self->{'methods'}{$method}) {
    $self->_set_error("unknown method: $method");
    $self->_return_error();
    return undef;
  }

  if ($self->{'cgi'}->param('PROXY_original_user')) {

    $self->{'cgi'}->param('PROXY_original_user') =~ /^([[:print:]]+)$/;
    my $proxied_user = $1;

    $self->{'cgi'}->delete('PROXY_original_user');

    #--- if we found that this is a request on behalf of another user,
    #--- let's verify that the proxier is one that this dispatcher will allow
    if ($proxied_user && $ENV{'REMOTE_USER'}) {
      my $proxier = $ENV{'REMOTE_USER'};

      #--- if so, do an environment swap so to the end method it's transparent
      if (grep {$_ eq $proxier} @{$self->{'allowed_proxy_users'}}) {
        $ENV{'REMOTE_USER'} = $proxied_user;
      }
      else {
        $self->_set_error("invalid proxy user: $proxier");
        $self->_return_error();
        return undef;
      }
    }
  }

  #--- have the method do its thing;
  $self->{'methods'}{$method}->handle_request( $self->{'cgi'},
                                               $self->{'output_handle'},
                                               $state,
                                               $self->{'default_input_validators'} );

  return 1;
}


=head2 get_method_list()

Method to retrives the list of registered methods

=cut

sub get_method_list{
  my $self        = shift;

  my @methods =  sort keys %{$self->{'methods'}};
  return \@methods;

}


=head2 get_method($name)

returns method ref based upon specified name

=cut

sub get_method{
  my $self        = shift;
  my $name  = shift;

  return $self->{'methods'}{$name};
}



=head2 get_error()

gets the last error encountered or undef.

=cut

sub get_error{
  my $self  = shift;
  return $self->{'error'};
}


=head2 _set_error()

protected method which sets a new error and prints it to stderr

=cut

sub _set_error{
  my $self  = shift;
  my $error = shift;

  #$self->{'error'} = Carp::longmess("$0 $error");
  $self->{'error'} = $error;
}


=head2 register_method()

This is used to register a web service method.  Three items are needed
to register a method: a method name, a function callback and a method configuration.

The callback will accept one input argument which will be a reference to the arguments
structure for that method, with the "value" attribute added.

The callback should return a pointer to the results data structure.

=cut
sub register_method{
  my $self  = shift;
  my $method_ref  = shift;

  #if(scalar ref($method_ref) ne  "GRNOC::WebService::Method"){
  # Carp::confess("method_ref of incorrect object type, needs to be of type GRNOC::WebService::Method");
  # return;
  #}

  my $method_name = $method_ref->get_name();
  if (!defined $method_name) {
    Carp::confess(ref $method_ref."->get_name() returned undef");
    return;
  }

  if (defined $self->{'methods'}{$method_name}) {
    Carp::confess("$method_name already exists");
    return;
  }

  $self->{'methods'}{$method_name} = $method_ref;
  if ($method_ref->{'is_default'}) {
    $self->{'default_method'} = $method_name;
  }
  #--- set the Dispatcher reference

  $method_ref->set_dispatcher($self);

  return 1;
}

=head2 add_default_input_validator()

This method takes a name, description, and callback subroutine as arguments.  This subroutine should return
either a true or false value which states whether or not the supplied input to a particular method is sane
(true) or tainted (false).  Every input parameter for every webservice method will execute the given default
input subroutine(s) and return an error unless every subroutine returns a true value when passing in the
supplied input.  A particular input parameter can override this behavior and ignore all default input
validator subroutines by passing the ignore_default_input_validators => 1 argument in the
add_input_parameter() method.

=cut

sub add_default_input_validator {

  my ( $self, %args ) = @_;

  my $name = $args{'name'};
  my $description = $args{'description'};
  my $callback = $args{'callback'};

  my $input_validator = {'name' => $name,
                         'description' => $description,
                         'callback' => $callback};

  my $defaults = $self->{'default_input_validators'};

  push( @$defaults, $input_validator );
}

=head2 activate_remote_methods()

This is used to activate the ability for this web service to proxy requests to another web service.

To activate remote methods we need a username and password for authorizing the "tunnel user", which is
the user that the remote webservice will see as trying to authorize. As well, it requires a list of authorized
remote webservices that are valid to send to as a security measure.

=cut


sub activate_remote_methods{
  my $self   = shift;
  my %params = @_;

  # prevent people from re-registering this method if they don't properly make use
  # of the mod_perl environment
  if (exists $self->{'methods'}->{'remote_method'}) {
    return 1;
  }

  my $default_user             = $params{'default_user'};
  my $default_pass             = $params{'default_pass'};
  my $default_realm            = $params{'default_realm'};
  my $specific_credentials     = $params{'specific_credentials'} || {};
  my $allowed_webservices      = $params{'allowed_webservices'};
  my $allowed_webservice_urns  = $params{'allowed_webservice_urns'};
  my $cookie_prefix            = $params{'cookie_prefix'};
  my $service_cache_file       = $params{'service_cache_file'};

  if (!defined($allowed_webservices) && !defined($allowed_webservice_urns)) {
    $self->_set_error("activate_remote_methods requires allowed_webservices and/or allowed_webservice_urls to be defined");
    return undef;
  }

  if (defined($allowed_webservices)) {

    my $remote_method = GRNOC::WebService::RemoteMethod->new(default_user         => $default_user,
                                                             default_pass         => $default_pass,
                                                             default_realm        => $default_realm,
                                                             credentials          => $specific_credentials,
                                                             allowed_webservices  => $allowed_webservices,
                                                             cookie_prefix        => $cookie_prefix
                                                            );


    $remote_method->add_input_parameter(
                                        name        => 'remote_webservice',
                                        pattern     => '^(.+)$',
                                        required    => 1,
                                        description => 'The full HTTP accessible name of the remote webservice.'
                                       );

    $remote_method->add_input_parameter(
                                        name        => 'remote_method_name',
                                        pattern     => '^(\w+)$',
                                        required    => 1,
                                        description => 'The name of the method at the destination webservice, what you would otherwise put as the method_name parameter.'
                                       );

    $remote_method->add_input_parameter(
                                        name        => 'remote_parameters',
                                        pattern     => '^(.*)$',
                                        required    => 1,
                                        description => 'The string of parameters to forward along to the remote webservice.',
                                        allow_null => 1
                                       );

    $remote_method->add_input_parameter(
	                                name         => 'timeout',
	                                pattern      => '^(\d+)$',
	                                required     => 1,
	                                default      => 15,
	                                description  => 'The timeout for the proxy to remote end request.'
	                               );

    $remote_method->add_input_parameter(
                                        name         => 'attachment',
                                        pattern      => '^(.*)$',
	                                required     => 0,
                                        attachment   => 1,
	                                description  => 'An attachment to send to the destination webservice'
	                               );

    $remote_method->add_input_parameter(
	                                name         => 'attachment_name',
	                                pattern      => '^(.+)$',
                                        default      => 'attachment',
	                                required     => 0,
	                                description  => 'What method parameter name to use when sending the attachment to the destination service.'
	                               );

    
    $self->register_method($remote_method)     or die "Unable to register remote method.";
  }

  if (defined($allowed_webservice_urns)) {

    my $remote_urn_method = GRNOC::WebService::RemoteMethod->new(name                     => "remote_urn_method",
                                                                 default_user             => $default_user,
                                                                 default_pass             => $default_pass,
                                                                 default_realm            => $default_realm,
                                                                 credentials              => $specific_credentials,
                                                                 allowed_webservice_urns  => $allowed_webservice_urns,
                                                                 callback                 => \&GRNOC::WebService::RemoteMethod::remote_urn_callback,
                                                                 cookie_prefix            => $cookie_prefix,
                                                                 service_cache_file       => $service_cache_file
                                                                );

    $remote_urn_method->add_input_parameter(
                                            name        => 'service_identifier',
                                            pattern     => '^(.+)$',
                                            required    => 1,
                                            description => 'The full URN of the remote service as it appears in the GRNOC Name Service'
                                           );

    $remote_urn_method->add_input_parameter(
                                            name        => 'remote_method_name',
                                            pattern     => '^(\w+)$',
                                            required    => 1,
                                            description => 'The name of the method at the destination webservice, what you would otherwise put as the method_name parameter.'
                                           );

    $remote_urn_method->add_input_parameter(
                                            name        => 'remote_parameters',
                                            pattern     => '^(.*)$',
                                            required    => 1,
                                            description => 'The string of parameters to forward along to the remote webservice.',
                                            allow_null => 1
                                           );

    $remote_urn_method->add_input_parameter(
	                                    name         => 'timeout',
	                                    pattern      => '^(\d+)$',
	                                    required     => 1,
	                                    default      => 15,
	                                    description  => 'The timeout for the proxy to remote end request.'
	                                   );

    $remote_urn_method->add_input_parameter(
	                                    name         => 'attachment',
	                                    pattern      => '^(.*)$',
	                                    required     => 0,
                                            attachment   => 1,
	                                    description  => 'An attachment to send to the destination webservice'
	                                   );

    $remote_urn_method->add_input_parameter(
	                                    name         => 'attachment_name',
	                                    pattern      => '^(.+)$',
                                            default      => 'attachment',
	                                    required     => 0,
	                                    description  => 'What method parameter name to use when sending the attachment to the destination service.'
	                                   );


    $self->register_method($remote_urn_method) or die "Unable to register remote urn method.";
  
    
    my $lookup_method = GRNOC::WebService::RemoteMethod->new(name                     => "remote_urn_lookup",
							     default_user             => $default_user,
							     default_pass             => $default_pass,
							     default_realm            => $default_realm,
							     credentials              => $specific_credentials,
							     allowed_webservice_urns  => $allowed_webservice_urns,
							     callback                 => \&GRNOC::WebService::RemoteMethod::remote_urn_lookup,
							     cookie_prefix            => $cookie_prefix,
							     service_cache_file       => $service_cache_file,
							     output_formatter         => \&JSON::XS::encode_json
	);
    
    $lookup_method->add_input_parameter(name        => "service_identifier",
					pattern     => '^(.+)$',
					required    => 1,
					description => "The full URN of the remote service as it appears in the GRNOC Name Service"
	);
    
    $self->register_method($lookup_method) or die "Unable to register remote urn lookup method.";
  }
  
  return 1;
  
}

=head1 ERROR HANDLING

When Dispatcher detects an error, it responds to the client in JSON format.

if response paramater "error" is set to 1 then this is an error response.
Error Details will be provided by "error_text" parameter.


Error handling is a little odd, in that if you choose to response in non-json
format, you would need to look at your response mimetype to figure out if
you had to deal with an error response or the result data.  Not sure this is the best
approach.



=head1 AUTHOR

GRNOC System Engineering, C<< <syseng at grnoc.iu.edu> >>

=head1 BUGS

Please report any bugs or feature requests via grnoc bugzilla




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc GRNOC::WebService


=head1 COPYRIGHT & LICENSE

Copyright(C) 2013 The Trustees of Indiana University, all rights reserved.

This program is for GRNOC internal use only, no redistribution is
permitted.


=cut

1;
