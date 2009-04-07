package Test::Mock::Class::ReturnTest;

use Test::Unit::Lite;

use Moose;
extends 'Test::Unit::TestCase';

use Test::Assert ':all';

use Test::Mock::Class;

has metamock => ( is => 'rw' );

sub set_up {
    my ($self) = @_;
    $self->metamock(
        Test::Mock::Class->create_mock_anon_class(
            class => 'Test::Mock::Class::Test::Dummy',
        )
    );
    assert_true($self->metamock->isa('Moose::Meta::Class'));
};

sub test_default_return {
    my ($self) = @_;
    $self->metamock->add_mock_return_value('a_method', 'aaa');
    my $mock = $self->metamock->new_object;
    assert_equals('aaa', $mock->a_method);
    assert_equals('aaa', $mock->a_method);
};

sub test_parametered_return {
    my ($self) = @_;
    $self->metamock->add_mock_return_value('a_method', 'aaa', args => [1, 2, 3]);
    my $mock = $self->metamock->new_object;
    assert_null($mock->a_method);
    assert_equals('aaa', $mock->a_method(1, 2, 3));
};

sub test_set_return_gives_object_reference {
    my ($self) = @_;
    my $object = Test::Mock::Class::Test::Dummy->new;
    $self->metamock->add_mock_return_value('a_method', $object, args => [1, 2, 3]);
    my $mock = $self->metamock->new_object;
    assert_equals($object, $mock->a_method(1, 2, 3));
};

sub test_return_value_can_be_chosen_just_by_pattern_matching_arguments {
    my ($self) = @_;
    $self->metamock->add_mock_return_value('a_method', 'aaa', args => [qr/hello/i]);
    my $mock = $self->metamock->new_object;
    assert_equals('aaa', $mock->a_method('Hello'));
    assert_null($mock->a_method('Goodbye'));
};

sub test_multiple_methods {
    my ($self) = @_;
    $self->metamock->add_mock_return_value('a_method', 100, args => [1]);
    $self->metamock->add_mock_return_value('a_method', 200, args => [2]);
    $self->metamock->add_mock_return_value('another_method', 10, args => [1]);
    $self->metamock->add_mock_return_value('another_method', 20, args => [2]);
    my $mock = $self->metamock->new_object;
    assert_equals(100, $mock->a_method(1));
    assert_equals(10, $mock->another_method(1));
    assert_equals(200, $mock->a_method(2));
    assert_equals(20, $mock->another_method(2));
};

sub test_return_sequence {
    my ($self) = @_;
    $self->metamock->add_mock_return_value_at(0, 'a_method', 'aaa');
    $self->metamock->add_mock_return_value_at(1, 'a_method', 'bbb');
    $self->metamock->add_mock_return_value_at(3, 'a_method', 'ddd');
    my $mock = $self->metamock->new_object;
    assert_equals('aaa', $mock->a_method);
    assert_equals('bbb', $mock->a_method);
    assert_null($mock->a_method);
    assert_equals('ddd', $mock->a_method);
};

sub test_complicated_return_sequence {
    my ($self) = @_;
    my $object = Test::Mock::Class::Test::Dummy->new;
    $self->metamock->add_mock_return_value_at(1, 'a_method', 'aaa', args => ['a']);
    $self->metamock->add_mock_return_value_at(1, 'a_method', 'bbb');
    $self->metamock->add_mock_return_value_at(2, 'a_method', $object, args => [qr//, 2]);
    $self->metamock->add_mock_return_value_at(2, 'a_method', "value", args => [qr//, 3]);
    $self->metamock->add_mock_return_value('a_method', 3, args => [3]);
    my $mock = $self->metamock->new_object;
    assert_null($mock->a_method);
    assert_equals('aaa', $mock->a_method('a'));
    assert_equals($object, $mock->a_method(1, 2));
    assert_equals(3, $mock->a_method(3));
    assert_null($mock->a_method);
};

sub test_multiple_method_sequences {
    my ($self) = @_;
    $self->metamock->add_mock_return_value_at(0, 'a_method', 'aaa');
    $self->metamock->add_mock_return_value_at(1, 'a_method', 'bbb');
    $self->metamock->add_mock_return_value_at(0, 'another_method', 'ccc');
    $self->metamock->add_mock_return_value_at(1, 'another_method', 'ddd');
    my $mock = $self->metamock->new_object;
    assert_equals('aaa', $mock->a_method);
    assert_equals('ccc', $mock->another_method);
    assert_equals('bbb', $mock->a_method);
    assert_equals('ddd', $mock->another_method);
};

sub test_sequence_fallback {
    my ($self) = @_;
    $self->metamock->add_mock_return_value_at(0, 'a_method', 'aaa', args => ['a']);
    $self->metamock->add_mock_return_value_at(1, 'a_method', 'bbb', args => ['a']);
    $self->metamock->add_mock_return_value('a_method', 'AAA');
    my $mock = $self->metamock->new_object;
    assert_equals('aaa', $mock->a_method('a'));
    assert_equals('AAA', $mock->a_method('b'));
};

sub test_method_interference {
    my ($self) = @_;
    $self->metamock->add_mock_return_value_at(0, 'another_method', 'aaa');
    $self->metamock->add_mock_return_value('a_method', 'AAA');
    my $mock = $self->metamock->new_object;
    assert_equals('AAA', $mock->a_method);
    assert_equals('aaa', $mock->another_method());
};

1;
