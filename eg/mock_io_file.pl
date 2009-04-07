#!/usr/bin/perl

use lib 'lib', '../lib';

use strict;
use warnings;

use constant::boolean;
use Test::Mock::Class ':all';
use Test::Assert ':all';

mock_class 'IO::Moose::File' => 'IO::File::Mock';

my $io = IO::File::Mock->new;
$io->mock_return_value( open => ( args => [qr//, 'r'], value => TRUE ) );
$io->mock_return_value( open => ( args => [qr//, 'w'], value => undef ) );
$io->mock_return_value_at( 1, getline => ( value => 'root:x:0:0:root:/root:/bin/bash' ) );
$io->mock_expect_never( 'close' );

# ok
assert_true( $io->open('/etc/passwd', 'r') );

# first line
assert_matches( qr/^root:[^:]*:0:0:/, $io->getline );

# eof
assert_null( $io->getline );

# access denied
assert_false( $io->open('/etc/passwd', 'w') );

# close was not called
$io->mock_tally;

print "OK\n";
