#--------------------------------------------------------------------
#----- Copyright(C) 2013 The Trustees of Indiana University
#--------------------------------------------------------------------
#----- $LastChangedBy: gmcnaugh $
#----- $LastChangedRevision: 9354 $
#----- $LastChangedDate: 2010-10-21 13:53:17 +0000 (Thu, 21 Oct 2010) $
#----- $HeadURL: svn+ssh://svn.grnoc.iu.edu/grnoc/perl-lib/GRNOC-WebService/trunk/lib/GRNOC/WebService/RemoteMethod.pm $
#----- $Id: RemoteMethod.pm 30682 2014-05-08 20:39:09Z gmcnaugh $
#-----
#----- object oriented backend web service interface for core data services
#-----
#---------------------------------------------------------------------
package GRNOC::WebService::RemoteMethod;

use strict;
use warnings;

use GRNOC::WebService::Client;
use GRNOC::WebService::Method;
use GRNOC::Config;

use CGI;
use JSON::XS;
use Encode;
use URI::Escape;

use Data::Dumper;
use Carp qw( longmess cluck );

use File::Temp qw(tempfile);

our @ISA = qw( GRNOC::WebService::Method );

=head1 NAME

GRNOC::WebService::RemoteMethod - GRNOC centric web service remote method object

    This is essentially a self contained wrapper that joins the WebService client module
    to the WebService module to allow for proxying calls to remote webservices via any one.

=head1 SYNOPSIS

This module provides web service programers a method to represent a web service method which then
is regegistered with GRNOC::WebService.


  use GRNOC::WebService::RemoteMethod;


  my $remote_method = GRNOC::WebService::RemoteMethod->new(user                => 'tunnel_user',
                                                           pass                => 'tunnel_pass',
                                                           allowed_webservices => ['http://db.grnoc.iu.edu/foo.cgi']);


=head1 FUNCTIONS


=head2 new()

Constructor that takes the following parameters:

=over

=item user

The username of the user that the remote service will see. Must obviously be authorized on the remote system.
This is NOT the username of the person who is calling the service but rather that of the proxy user who will pass
in the username of the original user via a parameter.

=item pass

The password of the user that the remote service will see.

=item allowed_webservices

An array of locations that this remote method is allowed to talk to.

=item cookie_prefix

The prefix where cookies will be stored after dealing with cosign. This defaults to /tmp/.

=back
    
=cut
    
sub new{
    my $that  = shift;
    my $class = ref($that) || $that;
    
    my %valid_parameter_list = (
				'default_user' => 1,
				'default_pass' => 1,
				'default_realm' => 1,
				'credentials' => 1,
				'allowed_webservices' => 1,
				'allowed_webservice_urns' => 1,
				'service_cache_file' => 1,
				'debug' => 1,
				'callback' => 1,
				'output_formatter' => 1,
				'description' => 1,
				'name' => 1,
				'cookie_prefix' => 1,
	                        'expires' => 1
				);
			
    #--- overide the defaults
    my %args = (
		name                => 'remote_method',
		description         => 'Proxies the request method name over to the request destination with the given parameters.', 
		output_formatter    => sub { my $response = shift; return $response; },
		callback	    => \&remote_callback,
                expires             => '-1d',
		debug               => 0,
		default_user        => undef,
		default_pass        => undef,
		default_realm       => undef,
		credentials         => {},
		allowed_webservices => undef,
		allowed_webservice_urns => undef,
		cookie_prefix       => '/tmp/',
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

    if (! defined $self->{'default_user'} || ! defined $self->{'default_pass'}){
	Carp::confess("remote method needs a default user and password");
	return;
    }
    
    if(!defined $self->{'allowed_webservices'} && !defined($self->{'allowed_webservice_urns'})){
	Carp::confess("remote method needs a list of allowed webservices and/or URNs to contact");
	return;
    }
    
    if(!defined($self->{'service_cache_file'}) && !defined($self->{'name_services'})){
	$self->{'service_cache_file'} = '/etc/grnoc/proxy/name_service.xml';
    }

    if(!defined($self->{'cookie_prefix'})){
        $self->{'cookie_prefix'} = '/tmp/';
    }
    
    $self->{'client'} =  GRNOC::WebService::Client->new(
							uid                 => $self->{'default_user'},
							passwd              => $self->{'default_pass'},
							realm               => $self->{'default_realm'},
							use_keep_alive      => 1,
							service_cache_file  => $self->{'service_cache_file'},
							name_services       => $self->{'name_services'},
							raw_output          => 1,
							usePost             => 0,
							debug               => 0
							);
    
    #--- our last read config time is now
    $self->{'config_mtime'} = time;

    return $self;
}

sub _return_error {
    my $self        = shift;
    my $cgi         = shift;
    my $fh          = shift;
    
    # it might be nice at some point to error the exact message from the far end back,
    # but this is useful for now
    # http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
    my $status = "502";

    warn $self->get_error();

    print $fh $cgi->header(-type    => 'text/plain', 
			   -expires => '-1d',
			   -status  => $status
	                  ); 
}

=head2 remote_urn_lookup

Callback that takes a service identifier (URN) and consults its configured name service
or name service cache for the URL associated with it.

=cut

sub remote_urn_lookup {
    my $method_ref = shift;
    my $p_ref      = shift;
    my $state_ref  = shift;

    my $urn        = $p_ref->{'service_identifier'}{'value'};

    my $remote_svc = $method_ref->{'client'};

    #--- reload our configuration file if we need to
    _update_cache_file($method_ref);

    #--- clear out the urls from a past time (ie under mod_perl)
    $remote_svc->clear_urls();


    my $is_allowed = 0;

    foreach my $allowed_urn (@{$method_ref->{'allowed_webservice_urns'}}){
	if ($allowed_urn eq $urn){
	    $is_allowed = 1;
	    last;
	}
    }

    if(!$is_allowed){
	$method_ref->set_error("No URLs found that remote method is set up to talk to for $urn");
	return undef;
    }

    if (! $remote_svc->set_service_identifier($urn) ){
	$method_ref->set_error($remote_svc->get_error());
	return undef;
    }

    my $weighted_urls = $remote_svc->{'urls'};

    my @urls;

    foreach my $weight (sort keys %$weighted_urls){
	foreach my $url (@{$weighted_urls->{$weight}}){
	    push(@urls, {"url" => $url, "weight" => $weight});
	}
    }

    return {'results' => \@urls};
}

=head2 remote_urn_callback

A special remote callback that supports redundancy in webservices. Passed in a service identifier URN it will look up all 
locations it knows about for that URN and try each one until it gets a response.

=cut


sub remote_urn_callback{

    my $method_ref = shift;
    my $p_ref      = shift;
    my $state_ref  = shift;

    my $urn           = $p_ref->{'service_identifier'}{'value'};
    my $remote_method = $p_ref->{'remote_method_name'}{'value'};
    my $remote_params = $p_ref->{'remote_parameters'}{'value'};

    # Clear out any manual headers from a previous request
    $method_ref->set_headers(undef);

    my $remote_svc    = $method_ref->{'client'};

    #--- This should never be true, we make the client at constructor time. This is just a safety
    if (!$remote_svc){
	$method_ref->set_error("Unable to make remote webservice client");
	return undef;
    }

    #--- Set our timeout value either to the default or whatever was passed in
    $remote_svc->set_timeout($p_ref->{'timeout'}{'value'});

    #--- Set up POST or GET
    if(defined $ENV{'REQUEST_METHOD'} && $ENV{'REQUEST_METHOD'} eq 'POST'){
	$remote_svc->{'usePost'} = 1;
    }else{
	$remote_svc->{'usePost'} = 0;
    }   

    #--- reload our configuration file if we need to
    _update_cache_file($method_ref);

    #--- load up credentials for this request, we might have different than the default for this urn
    _load_credentials($method_ref, $urn, $remote_svc);

    #--- clear out the urls from a past time (ie under mod_perl)
    $remote_svc->clear_urls();

    my $is_allowed = 0;

    foreach my $allowed_urn (@{$method_ref->{'allowed_webservice_urns'}}){
	if ($allowed_urn eq $urn){
	    $is_allowed = 1;
	    last;
	}
    }

    if(!$is_allowed){
	$method_ref->set_error("No URLs found that remote method is set up to talk to for $urn");
	return undef;
    }

    #--- if there was some trouble, likely in looking up the service identifier, bubble it up and bail
    if (! $remote_svc->set_service_identifier($urn) ){
	$method_ref->set_error($remote_svc->get_error());
	return undef;
    }

    #--- load up our cookies
    my $username = $remote_svc->{'uid'} || "noauth";
    $remote_svc->set_cookie_jar($method_ref->{'cookie_prefix'} . "/cookies-$username.txt");

    #--- get a hash version of the passed in parameters to pass to the client
    my ($to_pass, $fh) = _parse_remote_parameters($p_ref);

    #--- did we have a problem parsing?
    if (! defined $to_pass){
        return;
    }

    #--- the WS client automatically handles looking up the service name and trying the urls
    my $response = $remote_svc->$remote_method(%$to_pass);

    #--- if we had an attachment, clean up
    if ($fh){
        unlink($fh->filename);
    }

    #--- if we got something back, that means we probably navigated something properly so let's save cookies
    if ($response){
        $method_ref->set_headers($remote_svc->get_headers());
        $remote_svc->save_cookies();
    }
    #--- bubble an error back up from LWP
    else {
	$method_ref->set_error($remote_svc->get_error());
    }   

    return $response;     
}

=head2 remote_callback

The default callback for the remote methods, basically just sends the request on to the designated remote target if
it\'s in the list of allowed webservices and then forwards the response back to the original caller.

=cut

sub remote_callback{

    my $method_ref = shift;
    my $p_ref      = shift;
    my $state_ref  = shift;

    my $remote_service = $p_ref->{'remote_webservice'}{'value'};
    my $remote_method  = $p_ref->{'remote_method_name'}{'value'};
    my $remote_params  = $p_ref->{'remote_parameters'}{'value'};

    # Clear out any manual headers from a previous request
    $method_ref->set_headers(undef);
    
    my $is_valid = 0;
    
    foreach (@{$method_ref->{'allowed_webservices'}}){
	if ($_ eq $remote_service){
	    $is_valid = 1;
	    last;
	}
    }

    if (!$is_valid){
	$method_ref->set_error("remote method not set up to talk to $remote_service");
	return undef;
    }

    my $remote_svc = $method_ref->{'client'};

    #--- This should never be true, we make the client at constructor time. This is just a safety
    if (!$remote_svc){
	$method_ref->set_error("Unable to make remote webservice client");
	return undef;
    }  

    #--- Set our timeout value either to the default or whatever was passed in
    $remote_svc->set_timeout($p_ref->{'timeout'}{'value'});

    #--- Set up POST or GET
    if(defined $ENV{'REQUEST_METHOD'} && $ENV{'REQUEST_METHOD'} eq 'POST'){
	$remote_svc->{'usePost'} = 1;
    }else{
	$remote_svc->{'usePost'} = 0;
    }

    #--- clear out any urls from a past time (ie under mod_perl)
    $remote_svc->clear_urls();

    $remote_svc->set_url($remote_service);

    #--- load up our cookies
    my $username = $remote_svc->{'uid'} || "noauth";
    $remote_svc->set_cookie_jar($method_ref->{'cookie_prefix'} . "/cookies-$username.txt");

    #--- load up credentials for this request, we might have different than the default for this url
    _load_credentials($method_ref, $remote_service, $remote_svc);

    #--- get a hash version of the passed in parameters to pass to the client
    my ($to_pass, $fh) = _parse_remote_parameters($p_ref);

    if (! defined $to_pass){
        return;
    }

    my $response = $remote_svc->$remote_method(%$to_pass);

    #--- if we have an attachment, clean up
    if ($fh){
        unlink($fh->filename);
    }

    #--- if we got something back, that means we probably navigated something properly so let's save cookies
    if ($response){
        $method_ref->set_headers($remote_svc->get_headers());
        $remote_svc->save_cookies();
    }
    #--- bubble an error back up from LWP
    else {
	$method_ref->set_error($remote_svc->get_error());
    }

    return $response;   
}


=head2 _parse_remote_parameters

A helper function that takes in a string representing parameters for the end
webservice and creates a hashref out of them.

=cut


sub _parse_remote_parameters{
    my $p_ref = shift;

    my $remote_params = $p_ref->{'remote_parameters'}{'value'};

    my (%to_pass, $filehandle);

    if ($remote_params){
	# split up the params string based on ampersands
	my @params = split(/[&;]/, $remote_params);
    
	foreach my $param_pair (@params){
	    my ($name, $value) = split(/=/, $param_pair);	

	    $name = "" if ( !defined( $name ) );

	    # perl's CGI module (used in webservice client) is going to escape values,
	    # so unescape anything we were sent here to avoid double encoding issues

	    $name  =URI::Escape::uri_unescape( $name );
	    $value= URI::Escape::uri_unescape($value );

	    if (exists $to_pass{$name}){
		push @{$to_pass{$name}}, $value;
	    }
	    else{
		my @array;
		push(@array,$value);
		$to_pass{$name} = \@array;
	    }	
	}
    }

    #--- if we have an attachment specified, go ahead and read it in
    #--- and get it set up for the client
    if ($p_ref->{'attachment'}{'is_set'}){
        my $mime_type = $p_ref->{'attachment'}{'mime_type'};
        my $cgi_fh    = $p_ref->{'attachment'}{'value'};

        my $attachment_name = $p_ref->{'attachment_name'}{'value'};

        $filehandle = File::Temp->new(DIR => '/tmp/');

        binmode($cgi_fh);
        binmode($filehandle);

        my $buffer;
        while (read($cgi_fh, $buffer, 4096)){
            print $filehandle $buffer;
            if ($@){
                unlink($filehandle->filename);
                return;
            }
        }
        
        close($filehandle);
        
        if ($@){
            unlink($filehandle->filename);
            return;
        }
        
        $to_pass{$attachment_name} = {type      => 'file', 
                                      path      => $filehandle->filename,
                                      mime_type => $mime_type};
    }

    #--- add our special argument for the end dispatcher to know who really originated this request
    my $original_user               = $ENV{'REMOTE_USER'};
    $to_pass{'PROXY_original_user'} = $original_user;

    return (\%to_pass, $filehandle);    
}

=head2 _update_cache_file

Helper function that causes the internal webservice client to reload its config if it detects that 
it has changed.

=cut


sub _update_cache_file{
    my $method_ref = shift;

    my $client     = $method_ref->{'client'};

    # if we didn't have a service cache file for some reason (error, using name service, etc),
    # just return since there's nothing to do
    if (! $client->{'service_cache_file'}){
	return;
    }

    my $cache_filename = $client->{'service_cache_file'};

    # file doesn't exist? This is probably bad
    if (! -e $cache_filename){
	warn "Cache file \"$cache_filename\" does not exist?";
	return;
    }

    my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
	$atime, $mtime, $ctime, $blksize, $blocks) = stat($cache_filename);

    my $last_update_time = $method_ref->{'config_mtime'};

    # if the current modify time is newer than our last mtime, reload
    if ($mtime > $last_update_time){
	$client->_load_config();
	$method_ref->{'config_mtime'} = $mtime;
    } 

}

=head2 _load_credentials

 helper function to load authorization credentials for a service. initially use the default 
 credentials, then switch to service specific ones if applicable.

=cut

sub _load_credentials {
    my $method      = shift;
    my $key         = shift;
    my $client      = shift;

    my $credentials = $method->{'credentials'};

    my $username = $method->{'default_user'};
    my $password = $method->{'default_pass'};
    my $realm    = $method->{'default_realm'};

    if (exists $credentials->{$key}){
	my $data = $credentials->{$key};

	$username = $data->{'username'} if ($data->{'username'});
	$password = $data->{'password'} if ($data->{'password'});
	$realm    = $data->{'realm'}    if ($data->{'realm'});
    }

    $client->set_credentials(uid    => $username,
			     passwd => $password,
			     realm  => $realm
			     );

}

1; 
