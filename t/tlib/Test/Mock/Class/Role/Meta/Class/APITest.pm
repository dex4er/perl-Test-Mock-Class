package Test::Mock::Class::Role::Meta::Class::APITest;

use Test::Unit::Lite;

use Any::Moose;
use if Any::Moose::mouse_is_preferred, 'MouseX::Foreign';

extends 'Test::Unit::TestCase';

use Class::Inspector;
use Test::Assert ':all';

sub test_api {
    my @api = grep { ! /^_/ } @{ Class::Inspector->functions('Test::Mock::Class::Role::Meta::Class') };
    assert_deep_equals( [ qw(
        add_mock_constructor
        add_mock_method
        create_mock_anon_class
        create_mock_class
        meta
    ) ], \@api );
};

1;
