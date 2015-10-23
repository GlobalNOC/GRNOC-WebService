#--------------------------------------------------------------------
#----- Copyright(C) 2013 The Trustees of Indiana University
#--------------------------------------------------------------------
#----- $LastChangedBy: $
#----- $LastChangedRevision: $
#----- $LastChangedDate: $
#----- $HeadURL: $
#----- $Id: $
#-----
#----- This module exports variables to use for commonly used regexs
#----- of input parameters in a webservice method.  The idea is that
#----- instead of manually re-writing a regex each time, a webservice
#----- author can instead reference a variable defined in this module
#----- because it is probably already used elsewhere.
#--------------------------------------------------------------------

=head1 NAME

GRNOC::WebService::Regex - Exports commonly used regexs for input parameters

=head1 SYNOPSIS

use GRNOC::WebService::Regex;

$method->add_input_parameter( name => 'network',
                              pattern => $NUMBER_ID, # NUMBER_ID variable is automatically exported by this module
                              required => 1,
                              description => 'The abbreviated name of the administrative network.' );

=cut

package GRNOC::WebService::Regex;

use strict;
use warnings;

use Exporter;

use base 'Exporter';

our @EXPORT = qw($NUMBER_ID $NAME_ID $IP_ADDRESS $FLOAT $INTEGER $ANY_NUMBER $TEXT $MAC_ADDRESS $HOSTNAME $BOOLEAN);

=head1 VARIABLES

=over

=item NUMBER_ID

This regex should be used for unique identifiers which are strictly numbers.

=back

=cut

our $NUMBER_ID = '^(\d+)$';

=over

=item FLOAT

This regex should be used for numbers expected to have decimal places, including negatives.

=back

=cut

our $FLOAT = '^(\-?\d+.\d+)$';

=over

=item INTEGER

This regex should be used for any integer value, including negatives.

=back

=cut

our $INTEGER = '^(\-?\d+)$';

=over

=item ANY_NUMBER

This regex should be used for any number, including negatives and floats.

=back

=cut

our $ANY_NUMBER = '^(\-?\d+(.\d+)?)$';

=over

=item NAME_ID

This regex should be used for unique identifiers which are textual.

=back

=cut

our $NAME_ID = '^([[:print:]]+)$';

=over

=item TEXT

This regex should be used for unique identifiers which are textual.

=back

=cut

our $TEXT = '^([[:print:][:space:]]+)$';

=over

=item IP_ADDRESS

This regex should be used for IPv4 or IPv6 addresses.

=back

=cut

our $IP_ADDRESS = '^((?-xism::(?::[0-9a-fA-F]{1,4}){0,5}(?:(?::[0-9a-fA-F]{1,4}){1,2}|:(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})))|[0-9a-fA-F]{1,4}:(?:[0-9a-fA-F]{1,4}:(?:[0-9a-fA-F]{1,4}:(?:[0-9a-fA-F]{1,4}:(?:[0-9a-fA-F]{1,4}:(?:[0-9a-fA-F]{1,4}:(?:[0-9a-fA-F]{1,4}:(?:[0-9a-fA-F]{1,4}|:)|(?::(?:[0-9a-fA-F]{1,4})?|(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))))|:(?:(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))|[0-9a-fA-F]{1,4}(?::[0-9a-fA-F]{1,4})?|))|(?::(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))|:[0-9a-fA-F]{1,4}(?::(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))|(?::[0-9a-fA-F]{1,4}){0,2})|:))|(?:(?::[0-9a-fA-F]{1,4}){0,2}(?::(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))|(?::[0-9a-fA-F]{1,4}){1,2})|:))|(?:(?::[0-9a-fA-F]{1,4}){0,3}(?::(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))|(?::[0-9a-fA-F]{1,4}){1,2})|:))|(?:(?::[0-9a-fA-F]{1,4}){0,4}(?::(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))|(?::[0-9a-fA-F]{1,4}){1,2})|:))|(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))))$';

=over

=item MAC_ADDRESS

This regex should be used for MAC addresses, colon or dash delimited.

=back

=cut

our $MAC_ADDRESS = '^([0-9a-fA-F]{1,2})([:-])(([0-9a-fA-F]{1,2})\2){4}([0-9a-fA-F]{1,2})$';

=over

=item HOSTNAME

This regex should be used for RFC1035 host/domain names.

=back

=cut

our $HOSTNAME = '^((([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9]))$';

=over

=item BOOLEAN

This regex should be use for true/false boolean parameters.

=back

=cut

our $BOOLEAN = '^(0|1)$';

1;
