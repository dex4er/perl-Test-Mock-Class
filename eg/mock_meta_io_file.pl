#!/usr/bin/perl

use lib 'lib', '../lib';

use strict;
use warnings;

use constant::boolean;
use Test::Mock::Class ':all';
use Test::Assert ':all';

my $mock = Test::Mock::Class->create_mock_class( 'IO::File::Mock', class => 'IO::File' );

die $mock;

my $io = $mock->new_object;

$io->mock_returns( open => ( args => [qr//, 'r'], value => TRUE ) );
$io->mock_returns( open => ( args => [qr//, 'w'], value => undef ) );
$io->mock_returns_at( 1, getline => ( value => 'root:x:0:0:root:/root:/bin/bash' ) );

# ok
assert_true( $io->open('/etc/passwd', 'r') );

# first line
assert_matches( qr/^root:[^:]*:0:0:/, $io->getline );

# eof
assert_null( $io->getline );

# access denied
assert_false( $io->open('/etc/passwd', 'w') );

print "OK\n";
