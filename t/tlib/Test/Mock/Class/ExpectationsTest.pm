package Test::Mock::Class::ExpectationsTest;

use Test::Unit::Lite;

use Moose;
extends 'Test::Unit::TestCase';
with 'Test::Mock::Class::MockTestRole';

use Test::Assert ':all';

sub test_setting_expectation_on_non_method_throws_error {
    my ($self) = @_;
    my $mock = $self->mock;
    $mock->mock_expect_maximum_call_count('a_mising_error', 2);
}

1;
