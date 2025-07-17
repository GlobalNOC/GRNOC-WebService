#!/usr/bin/perl

use strict;
use warnings;

use ExtUtils::MakeMaker;
use Apache::TestMM qw(test clean);
use Apache::TestRunPerl ();
use FindBin;

sub MY::postamble { <<"END"; }

rpm: dist
	rpmbuild -ta GRNOC-WebService-\$(VERSION).tar.gz

test_jenkins :
	make test PERL_TEST_HARNESS_DUMP_TAP=$FindBin::Bin/tap/

END

WriteMakefile(
              NAME                => 'GRNOC::WebService',
              AUTHOR              => 'GRNOC Software Engineering',
              VERSION_FROM        => 'lib/GRNOC/WebService.pm',
              PL_FILES            => {},
              PREREQ_PM => {
                           },
              dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
              clean               => { FILES => 'GRNOC-WebService*' },
             );
