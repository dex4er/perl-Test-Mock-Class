package Test::Mock::Class::GenerateTest;

use Test::Unit::Lite;

use Any::Moose;
use if Any::Moose::mouse_is_preferred, 'MouseX::Foreign';

extends 'Test::Unit::TestCase';

use Test::Assert ':all';

use Test::Mock::Class;

sub test_mock_class {
    my $meta = Test::Mock::Class->create_mock_class(
        'Test::Mock::Class::Test::Dummy::MockGenerated',
        class => 'Test::Mock::Class::Test::Dummy',
    );
    assert_true($meta->isa(any_moose('::Meta::Class')));
    assert_true(Test::Mock::Class::Test::Dummy::MockGenerated->isa('Test::Mock::Class::Test::Dummy::MockGenerated'));
};

1;
