package Test::Mock::Class::ExpectationsTest;

use Test::Unit::Lite;

use Moose;
extends 'Test::Unit::TestCase';
with 'Test::Mock::Class::MockBaseTestRole';

use Test::Assert ':all';

sub test_setting_expectation_on_non_method_throws_error {
    my ($self) = @_;
    my $mock = $self->mock;
    assert_raises( qr/Cannot set expected arguments as no method/, sub {
        $mock->mock_expect_maximum_call_count('a_mising_error', 2);
    } );
};

sub test_max_calls_detects_overrun {
    my ($self) = @_;
    my $mock = $self->mock;
    $mock->mock_expect_maximum_call_count('a_method', 2);
    $mock->a_method;
    $mock->a_method;
    assert_raises( qr/Maximum call count/, sub {
        $mock->a_method;
    } );
};

sub test_tally_on_max_calls_sends_pass_on_underrun {
    my ($self) = @_;
    my $mock = $self->mock;
    $mock->mock_expect_maximum_call_count('a_method', 2);
    $mock->a_method;
    $mock->a_method;
    $mock->mock_tally;
};

sub test_expect_never_detects_overrun {
    my ($self) = @_;
    my $mock = $self->mock;
    $mock->mock_expect_never('a_method');
    assert_raises( qr/Maximum call count/, sub {
        $mock->a_method;
    } );
};

1;
