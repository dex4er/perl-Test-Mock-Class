package Test::Mock::Class::ExpectationsThatPassTest;

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

sub test_any_argument {
    my ($self) = @_;
    $self->metamock->add_mock_expectation('a_method', args => [qr//]);
    my $mock = $self->metamock->new_object;
    $mock->a_method(1);
    $mock->a_method('hello');
};

sub test_any_two_arguments {
    my ($self) = @_;
    $self->metamock->add_mock_expectation('a_method', args => [qr//, qr//]);
    my $mock = $self->metamock->new_object;
    $mock->a_method(1, 2);
};

sub test_specific_argument {
    my ($self) = @_;
    $self->metamock->add_mock_expectation('a_method', args => [1]);
    my $mock = $self->metamock->new_object;
    $mock->a_method(1);
};

sub test_arguments_in_sequence {
    my ($self) = @_;
    $self->metamock->add_mock_expectation_at(0, 'a_method', args => [1, 2]);
    $self->metamock->add_mock_expectation_at(1, 'a_method', args => [3, 4]);
    my $mock = $self->metamock->new_object;
    $mock->a_method(1, 2);
    $mock->a_method(3, 4);
};

sub test_at_least_once_satisfied_by_one_call {
    my ($self) = @_;
    $self->metamock->add_mock_expectation_at_least_once('a_method');
    my $mock = $self->metamock->new_object;
    $mock->a_method;
};

sub test_at_least_once_satisfied_by_two_calls {
    my ($self) = @_;
    $self->metamock->add_mock_expectation_at_least_once('a_method');
    my $mock = $self->metamock->new_object;
    $mock->a_method;
    $mock->a_method;
};

sub test_once_satisfied_by_one_call {
    my ($self) = @_;
    $self->metamock->add_mock_expectation_once('a_method');
    my $mock = $self->metamock->new_object;
    $mock->a_method;
};

sub test_minimum_calls_satisfied_by_enough_calls {
    my ($self) = @_;
    $self->metamock->add_mock_expectation_minimum_call_count('a_method', 1);
    my $mock = $self->metamock->new_object;
    $mock->a_method;
};

sub test_minimum_calls_satisfied_by_too_many_calls {
    my ($self) = @_;
    $self->metamock->add_mock_expectation_minimum_call_count('a_method', 3);
    my $mock = $self->metamock->new_object;
    $mock->a_method;
    $mock->a_method;
    $mock->a_method;
    $mock->a_method;
};

sub test_maximum_calls_satisfied_by_enough_calls {
    my ($self) = @_;
    $self->metamock->add_mock_expectation_maximum_call_count('a_method', 1);
    my $mock = $self->metamock->new_object;
    $mock->a_method;
};

sub test_maximum_calls_satisfied_by_no_calls {
    my ($self) = @_;
    $self->metamock->add_mock_expectation_maximum_call_count('a_method', 1);
    my $mock = $self->metamock->new_object;
};

1;
