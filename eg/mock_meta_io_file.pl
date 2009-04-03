#!/usr/bin/perl

use lib 'lib', '../lib';

use strict;
use warnings;

use constant::boolean;
use Test::Mock::Class ':all';
use Test::Assert ':all';

use Smart::Comments;

my $mock = Test::Mock::Class->create_mock_anon_class( class => 'IO::File' );
$mock->add_mock_return( open => ( args => [qr//, 'r'], value => TRUE ) );
$mock->add_mock_return( open => ( args => [qr//, 'w'], value => undef ) );
$mock->add_mock_return_at( 1, getline => ( value => 'root:x:0:0:root:/root:/bin/bash' ) );

## $mock

my $io = $mock->new_object;

### $io


# ok
assert_true( $io->open('/etc/passwd', 'r') );

# first line
assert_matches( qr/^root:[^:]*:0:0:/, $io->getline );

# eof
assert_null( $io->getline );

# access denied
assert_false( $io->open('/etc/passwd', 'w') );

print "OK\n";
