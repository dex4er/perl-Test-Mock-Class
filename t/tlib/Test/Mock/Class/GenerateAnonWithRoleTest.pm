package Test::Mock::Class::AnonClassWithRoleTest;

use Test::Unit::Lite;

use Moose;
extends 'Test::Unit::TestCase';

sub test_mock_anon_class_with_role {
    my $metamock = Test::Mock::Class->create_mock_anon_class(
        class => 'Test::Mock::Class::Test::Dummy',
        roles => ['Test::Mock::Class::RoleTestRole'],
    );
    assert_true($metamock->isa('Moose::Meta::Class'));
    my $mock = $metamock->new_object;
    assert_true($mock->does('Test::Mock::Class::Role::Object'));
    assert_true($mock->does('Test::Mock::Class::RoleTestRole'));
    assert_true($mock->test_role_method);
};


1;
