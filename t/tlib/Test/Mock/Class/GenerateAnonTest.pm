package Test::Mock::Class::GenerateAnonTest;

use Test::Unit::Lite;

use Moose;
extends 'Test::Unit::TestCase';

use Test::Assert ':all';

use Test::Mock::Class;

has meta => ( is => 'rw' );

sub set_up {
    my ($self) = @_;
    $self->meta(
        Test::Mock::Class->create_mock_anon_class(
            class => 'Test::Mock::Class::Test::Dummy',
        )
    );
    assert_true($self->meta->isa('Moose::Meta::Class'));
};

sub test_mock_anon_class {
    my ($self) = @_;

    my $mock = $self->meta->new_object;
    assert_true($mock->can('a_method'));
    assert_null($mock->a_method);
};

sub test_mock_add_method {
    my ($self) = @_;
    $self->meta->add_mock_method('extra_method');

    my $mock = $self->meta->new_object;
    assert_true($mock->can('extra_method'));
    assert_null($mock->extra_method);
};

sub test_mock_add_constructor {
    my ($self) = @_;
    $self->meta->add_mock_constructor('extra_new');

    my $mock = $self->meta->new_object;
    assert_true($mock->can('extra_new'));

    my $mock2 = $mock->extra_new;
    assert_true($mock2->can('extra_new'));
};

1;
