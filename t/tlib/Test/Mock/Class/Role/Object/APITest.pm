package Test::Mock::Class::Role::Object::APITest;

use Test::Unit::Lite;

use Any::Moose;
use if Any::Moose::mouse_is_preferred, 'MouseX::Foreign';

extends 'Test::Unit::TestCase';

use Class::Inspector;
use Test::Assert ':all';

sub test_api {
    my @api = grep { ! /^_/ } @{ Class::Inspector->functions('Test::Mock::Class::Role::Object') };
    assert_deep_equals( [ qw(
        meta
        mock_expect
        mock_expect_at
        mock_expect_at_least_once
        mock_expect_call_count
        mock_expect_maximum_call_count
        mock_expect_minimum_call_count
        mock_expect_never
        mock_expect_once
        mock_invoke
        mock_return
        mock_return_at
        mock_tally
        mock_throw
        mock_throw_at
    ) ], \@api );
};

1;
