use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'WebObvius::CatalystUtils' }
BEGIN { use_ok 'WebObvius::CatalystUtils::Controller::Utils' }

ok( request('/utils')->is_success, 'Request should succeed' );
done_testing();
