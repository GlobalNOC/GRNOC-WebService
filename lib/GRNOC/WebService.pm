#--------------------------------------------------------------------
#----- Copyright(C) 2015 The Trustees of Indiana University
#--------------------------------------------------------------------
#----- object oriented backend web service interface for core data services
#-----
#---------------------------------------------------------------------
use warnings;
use strict;

package GRNOC::WebService;

our $VERSION = '1.2.16';

require GRNOC::WebService::Dispatcher;
require GRNOC::WebService::Method;
require GRNOC::WebService::RemoteMethod;
require GRNOC::WebService::Client;

1;

=head1 NAME

GRNOC::WebService - GRNOC WebService Library for perl

=head1 SYNOPSIS

  use GRNOC::WebService;
  print "This is version $GRNOC::WebService::VERSION\n";


=head1 DESCRIPTION

The WebService collection is a set of perl modules which are used to
provide and interact with GRNOC web services using Cosign Authentication
and CGI/* formats.

The main features of the library are:

=over

=item *

Provides easy to use interface for implementing services and service
clients that work with our systems

=item *

Provides an object oriented model for communcation with services

=item *

Consistent base for all services, using proper POD documetation, named
parameters and OO where sensible.

=back


=head1 OVERVIEW OF CLASSES AND PACKAGES

This table should give you a quick overview of the classes provided by the
library. Indentation shows class inheritance.

 GRNOC::WebService::Method    -- Web Service Method handler object
 GRNOC::WebService::Dispatcher  -- Web Service Dispatcher object
 GRNOC::WebService::Client  -- Web Service Client ojbect interface


=head1 AUTHOR

GRNOC System Engineering, C<< <syseng at grnoc.iu.edu> >>

=head1 BUGS

Please report any bugs or feature requests via grnoc bugzilla




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc GRNOC::WebService

=cut

1;
