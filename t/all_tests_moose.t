#!/usr/bin/perl

use 5.006;

use strict;
use warnings;

use Test::Unit::Lite;

$ENV{ANY_MOOSE} = 'Moose';

local $SIG{__WARN__} = sub { require Carp; Carp::confess(@_) };

eval {
    require Moose;
};
if ($@) {
    print "1..0 # SKIP Moose required\n";
}
else {
    Test::Unit::HarnessUnit->new->start('Test::Unit::Lite::AllTests');
};
