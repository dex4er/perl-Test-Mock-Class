package Test::Mock::Class::MockTestRole;

use Moose::Role;

use Test::Assert ':all';

use Test::Mock::Class;

has metamock => ( is => 'rw', clearer => 'clear_metamock' );
has mock     => ( is => 'rw', clearer => 'clear_mock' );

sub set_up {
    my ($self) = @_;
    my $metamock = $self->metamock(
        Test::Mock::Class->create_mock_anon_class(
            class => 'Test::Mock::Class::Test::Dummy',
        )
    );
    assert_true($metamock->isa('Moose::Meta::Class'));
    my $mock = $self->mock($metamock->new_object);
    assert_true($mock->does('Test::Mock::Class::Role::Object'));
};

sub tear_down {
    my ($self) = @_;
    $self->mock->mock_tally;
    $self->clear_mock;
    $self->clear_metamock;
};

1;
