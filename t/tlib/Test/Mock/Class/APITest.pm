package Test::Mock::Class::APITest;

use Test::Unit::Lite;

use Any::Moose;
use if Any::Moose::mouse_is_preferred, 'MouseX::Foreign';

extends 'Test::Unit::TestCase';

use Class::Inspector;
use Test::Assert ':all';

sub test_api {
    my @api = grep { ! /^_/ } @{ Class::Inspector->functions('Test::Mock::Class') };
    assert_deep_equals( [ qw(
        add_mock_constructor
        add_mock_method
        create_mock_anon_class
        create_mock_class
        import
        meta
        mock_base_object_role
        mock_constructor_methods_regexp
        mock_ignore_methods_regexp
    ) ], \@api );
};

1;
