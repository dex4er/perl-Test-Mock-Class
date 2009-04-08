package Test::Mock::Class::MockTallyTestRole;

use Moose::Role;

around tear_down => sub {
    my ($super, $self) = @_;
    $self->mock->mock_tally;
    return $self->$super();
};

1;
