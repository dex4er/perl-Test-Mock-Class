package Test::Mock::Class::MockTallyTestRole;

use Any::Moose 'Role';

around tear_down => sub {
    my ($next, $self) = @_;
    $self->mock->mock_tally;
    return $self->$next();
};

1;
