#!/usr/bin/perl -c

package Test::Mock::Class::Role::Object;

=head1 NAME

Test::Mock::Class::Role::Object - Base class for mocked class

=head1 SYNOPSIS

  package My::Class::Mock;
  use Moose;
  extends 'Test::Mock::Class::Base', 'My::Class';

  sub my_method {
      my $self = shift;
      $self->SUPER::invoke('my_method', @_);  
  };

=head1 DESCRIPTION

Base class for mocked class.

=for readme stop

=cut

use 5.006;

use strict;
use warnings;

our $VERSION = '0.01';

use Moose::Role;


use constant::boolean;
use Smart::Comments;
use Scalar::Util 'refaddr';
use Test::Assert ':all';


use namespace::clean -except => 'meta';


# Our attributes needs to be inside-out because we don't know
# which type is instance (hashref, globref, etc.)

=head1 ATTRIBUTE

=over

=item _mock_attribute : HashRef

The additional state of mock object is stored in this inside-out attribute. 

=back

=cut

our %_mock_attribute = ();

sub _mock_attribute {
      my ($self) = @_;
      if (not defined $_mock_attribute{refaddr $self}) {
          $_mock_attribute{refaddr $self} = {};
      };
      return $_mock_attribute{refaddr $self};
};


=head1 METHODS

=over

=item _mock_invoke(I<method> : Str, I<args> : Array) : Any

Returns the expected value for the method name and checks expectations. Will
generate any test assertions as a result of expectations if there is a test
present.

=cut

sub _mock_invoke {
    my ($self, $method, @args) = @_;
    my $timing = $self->_mock_add_call($method, @args);
    $self->_mock_check_expectations($method, $timing, @args);
    return $self->_mock_emulate_call($method, $timing, @args);
};

=item _mock_emulate_call(I<method> : Str, I<timing> : Int, I<args> : Array) : Any

Finds the return value matching the incoming arguments. If there is no
matching value found then an error is triggered.

=cut

sub _mock_emulate_call {
    my ($self, $method, $timing, @args) = @_;

    my ($matching, $action) = ('return', 'value');

    return unless defined $self->_mock_attribute->{$matching}{$method};

    return $self->_mock_method_matching(
        $matching, $action, $method, $timing, @args
    );
};


=item _mock_check_expectations(I<method> : Str, I<timing> : Num, I<args> : Array) : Self

Tests the arguments against expectations.

=cut

sub _mock_check_expectations {
    my ($self, $method, $timing, @args) = @_;

    my ($matching, $action) = ('expectation', 'assertion');

    return unless defined $self->_mock_attribute->{$matching}{$method};

    my $value = $self->_mock_method_matching(
        $matching, $action, $method, $timing, @args
    );

    fail([
        'Wrong arguments for method (%s) at call (%d)', $method, $timing
    ]) unless defined $value;
    
    return $value;
};


=item mock_tally() : Self

Check the expectations at the end.

=cut

sub mock_tally {
    my ($self) = @_;

    return if not defined $self->_mock_attribute->{expectation}
              or (ref $self->_mock_attribute->{expectation} || '') ne 'HASH';

    foreach my $method (keys %{ $self->_mock_attribute->{expectation} }) {
        next if not defined $self->_mock_attribute->{expectation}{$method}
                or (ref $self->_mock_attribute->{expectation}{$method} || '') ne 'ARRAY';

        foreach my $rule (@{ $self->_mock_attribute->{expectation}{$method} }) {
            if (defined $rule->{count}) {
                my $count = $rule->{call} || 0;
                fail([
                    'Expected call count (%d) for method (%s) with calls (%d)',
                    $rule->{count}, $method, $count
                ]) if ($count != $rule->{count});
            };
            if (defined $rule->{minimum}) {
                my $count = $rule->{call} || 0;
                fail([
                    'Minimum call count (%d) for method (%s) with calls (%d)',
                    $rule->{minimum}, $method, $count
                ]) if ($count < $rule->{minimum}); 
            };
        };
    };

    return $self;
};

=item _mock_method_matching(I<matchings> : ArrayRef, I<action> : Str, I<method> : Str, I<timing> : Num, I<args> : Array) : Any

Do matching for method and do some action if succeed.

This private method is shared between C<_mock_emulate_call> and
C<_mock_check_expectations> methods.

=over

=item matchings

Name of C<_mock_attribute> slot which contains matching.

=item action

Name of slot which contains returns value or assertion.

=item method

Method name.

=item timing

Current call number.

=item args

Calling arguments to match.

=back

=cut

sub _mock_method_matching {
    my ($self, $matching, $action, $method, $timing, @args) = @_;

    return if not defined $self->_mock_attribute->{$matching}{$method}
              or (ref $self->_mock_attribute->{$matching}{$method} || '') ne 'ARRAY';

    RULE:
    foreach my $rule (@{ $self->_mock_attribute->{$matching}{$method} }) {
        if ($rule->{at}) {
            next unless $timing == $rule->{at};
        };

        if (exists $rule->{args}) {
            my @rule_args = (ref $rule->{args} || '') eq 'ARRAY'
                            ? @{ $rule->{args} }
                            : ( $rule->{args} );

            # number of args matches?
            next unless @args == @rule_args;

            # iterate args
            foreach my $i (0 .. @rule_args - 1) {
                my $rule_arg = $rule_args[$i];
                if ((ref $rule_arg || '') eq 'Regexp') {
                    next RULE unless $args[$i] =~ $rule_arg;
                }
                elsif (ref $rule_arg) {
                    # TODO: do not use eval
                    eval {
                        assert_deep_equals($args[$i], $rule_arg);
                    };
                    next RULE if $@;
                }
                else {
                    # TODO: do not use eval
                    eval {
                        assert_equals($args[$i], $rule_arg);
                    };
                    next RULE if $@;
                };
            };
        };

        $rule->{call} ++;

        fail([
            'Maximum call count (%d) for method (%s) at call (%d)',
            $rule->{maximum}, $method, $timing
        ]) if (defined $rule->{maximum} and $rule->{call} > $rule->{maximum});

        if (ref $rule->{$action} eq 'CODE') {
            return $rule->{$action}->($method, $timing, @args);
        }
        elsif (defined $rule->{$action}) {
            return $rule->{$action};
        };
    };

    return undef;
};


=item _mock_add_call(I<method> : Str, I<args> : Array) : Int

Adds one to the call count of a method and returns current value.

=cut

sub _mock_add_call {
    my ($self, $method, @args) = @_;

    assert_not_null($method) if ASSERT;
    return ++$self->_mock_attribute->{call}{$method};
};

sub mock_add_method {
    my ($self, $method) = @_;
    $self->meta->add_method( $method => sub {
        my $method_self = shift;
        return $method_self->_mock_invoke($method, @_);
    } );
    return $self;
};


sub mock_add_constructor {
    my ($self, $constructor) = @_;
    $self->meta->add_method( $constructor => sub {
        my $class = shift;
        $class->_mock_invoke($constructor, @_) if blessed $class;
        my $method_self = $class->meta->new_object(@_);
        $method_self->_mock_invoke($constructor, @_);
        return $method_self;
    } );
    return $self;
};

=item mock_returns( I<method> : Str, :I<value> : Any, :I<at> : Int, :I<args> : ArrayRef[Any] ) : Self

Sets a return for a parameter list that will be passed on by call to this
method that match.

The first value is returned if more than one parameter list matches method's
arguments.  The undef value is returned if none of parameters matches.

=over

=item method

Method name.

=item value

Returned value.

  $m->mock_returns( open => ( value => 1 ) );

If value is coderef, then it is called with method name, current timing
and original arguments as arguments.

  $m->mock_returns( sequence => (
      value => sub { qw{one two three}[ $_[1]-1 ] }
  ) );

=item at

Value is returned only for current timing.

  $m->mock_returns( sequence => ( at => 1, value => 'one' ) );
  $m->mock_returns( sequence => ( at => 2, value => 'two' ) );
  $m->mock_returns( sequence => ( at => 3, value => 'three' ) );

=item args

Value is returned only if method is called with proper argument.

  $m->mock_returns(
      get_value => ( args => ['dbuser'], value => 'admin' )
  );
  $m->mock_returns(
      get_value => ( args => ['dbpass'], value => 'secret' )
  );
  $m->mock_returns(
      get_value => ( args => [qr/.*/], value => sub { $_[2] } )
  );

=back

=cut

sub mock_returns {
    my ($self, $method, %params) = @_;

    Exception::Argument->throw(
        message => 'Usage: $mock->mock_returns( METHOD => PARAMS )'
    ) unless defined $method;

    push @{ $self->_mock_attribute->{return}{$method} } => \%params;

    return $self;
};


=item mock_returns_at( I<at> : Int, I<method> : Str, :I<args> : ArrayRef[Any] ) : Self

Convenience method for returning a value upon the method call.

=cut

sub mock_returns_at {
    my ($self, $at, $method, %params) = @_;
    
    Exception::Argument->throw(
        message => 'Usage: $mock->mock_returns_at( AT, METHOD => PARAMS )'
    ) unless defined $at and defined $method;

    return $self->mock_returns( $method => %params, at => $at );
};


=item mock_expect( I<method> : Str, :I<at> : Int, :I<minimum> : Int, :I<maximum> : Int, :I<count> : Int, :I<args> : ArrayRef[Any] ) : Self

Sets up an expected call with a set of expected parameters in that call. All
calls will be compared to these expectations regardless of when the call is
made.

=cut

sub mock_expect {
    my ($self, $method, %params) = @_;
    
    Exception::Argument->throw(
        message => 'Usage: $mock->mock_expect( METHOD => PARAMS )'
    ) unless defined $method;

    push @{ $self->_mock_attribute->{expectation}{$method} } => {
        %params,
    };

    return $self;    
};


=item mock_expect_at( I<at> : Int, I<method> : Str, :I<args> : ArrayRef[Any] ) : Self

Sets up an expected call with a set of expected parameters in that call.

=cut

sub mock_expect_at {
    my ($self, $at, $method, %params) = @_;
    
    Exception::Argument->throw(
        message => 'Usage: $mock->mock_expect_at( AT, METHOD => PARAMS )'
    ) unless defined $at and defined $method;

    return $self->mock_expect( $method => %params, at => $at );
};


=item mock_expect_call_count( I<method> : Str, I<count> : Int, :I<args> : ArrayRef[Any] ) : Self

Sets an expectation for the number of times a method will be called. The
C<mock_tally> method have to be used to check this.

=cut

sub mock_expect_call_count {
    my ($self, $method, $count, %params) = @_;
    
    Exception::Argument->throw(
        message => 'Usage: $mock->mock_expect_call_count( METHOD, COUNT => PARAMS )'
    ) unless defined $method and defined $count;

    return $self->mock_expect( $method => %params, count => $count );
};


=item mock_expect_maximum_call_count( I<method> : Str, I<count> : Int, :I<args> : ArrayRef[Any] ) : Self

Sets the number of times a method may be called before a test failure is
triggered.

=cut

sub mock_expect_maximum_call_count {
    my ($self, $method, $count, %params) = @_;
    
    Exception::Argument->throw(
        message => 'Usage: $mock->mock_expect_maximum_call_count( METHOD, COUNT => PARAMS )'
    ) unless defined $method and defined $count;

    return $self->mock_expect( $method => %params, maximum => $count );
};


=item mock_expect_minimum_call_count( I<method> : Str, I<count> : Int, :I<args> : ArrayRef[Any] ) : Self

Sets the number of times to call a method to prevent a failure on the tally.

=cut

sub mock_expect_minimum_call_count {
    my ($self, $method, $count, %params) = @_;
    
    Exception::Argument->throw(
        message => 'Usage: $mock->mock_expect_minimum_call_count( METHOD, COUNT => PARAMS )'
    ) unless defined $method and defined $count;

    return $self->mock_expect( $method => %params, minimum => $count );
};


=item mock_expect_never( I<method> : Str, :I<args> : ArrayRef[Any] ) : Self

Convenience method for barring a method call.

=cut

sub mock_expect_never {
    my ($self, $method, %params) = @_;
    
    Exception::Argument->throw(
        message => 'Usage: $mock->mock_expect_never( METHOD => PARAMS )'
    ) unless defined $method;

    return $self->mock_expect( $method => %params, maximum => 0 );
};


=item mock_expect_once( I<method> : Str, :I<args> : ArrayRef[Any] ) : Self

Convenience method for a single method call.

=cut

sub mock_expect_once {
    my ($self, $method, %params) = @_;
    
    Exception::Argument->throw(
        message => 'Usage: $mock->mock_expect_once( METHOD => PARAMS )'
    ) unless defined $method;

    return $self->mock_expect( $method => %params, count => 1 );
};


=item mock_expect_at_least_once( I<method> : Str, :I<args> : ArrayRef[Any] ) : Self

Convenience method for requiring a method call.

=cut

sub mock_expect_at_least_once {
    my ($self, $method, %params) = @_;
    
    Exception::Argument->throw(
        message => 'Usage: $mock->mock_expect_at_least_once( METHOD => PARAMS )'
    ) unless defined $method;

    return $self->mock_expect( $method => %params, minimum => 1 );
};


=item mock_throw( I<method> : Str, :I<at> : Int, :I<exception> : Str, :I<args> : ArrayRef[Any] ) : Self

Sets up a trigger to throw an exception upon the method call.

=cut

sub mock_throw {
    my ($self, $method, %params) = @_;
    
    Exception::Argument->throw(
        message => 'Usage: $mock->mock_throw( METHOD => PARAMS )'
    ) unless defined $method;

    my $exception = $params{exception} || 'Exception::Assertion';

    push @{ $self->_mock_attribute->{return}{$method} } => {
        %params,
        value => sub {
            $exception->throw(
                message => ['Throw on method (%s)', $method], 
                %params
            )
        },
    };

    return $self;    
};


=item mock_throw_at( I<at> : Int, I<method> : Str, :I<args> : ArrayRef[Any] ) : Self

Convenience method for throwing an error upon the method call.

=cut

sub mock_throw_at {
    my ($self, $at, $method, %params) = @_;
    
    Exception::Argument->throw(
        message => 'Usage: $mock->mock_throw_at( AT, METHOD => PARAMS )'
    ) unless defined $at and defined $method;

    return $self->mock_throw( $method => %params, at => $at );
};


sub DESTROY {
    my ($self) = @_;
    delete $_mock_attribute{refaddr $self};
};

1;


=back

=begin umlwiki

= Class Diagram =

[                    Test::Mock::Class::Reflection
 -----------------------------------------------------------------------
 -----------------------------------------------------------------------
 class_exists() : Bool
                                                                        ]

=end umlwiki

=head1 SEE ALSO

L<Moose>.

=head1 BUGS

The API is not stable yet and can be changed in future.

=for readme continue

=head1 AUTHOR

Piotr Roszatycki <dexter@cpan.org>

=head1 LICENSE

Based on SimpleTest, an open source unit test framework for the PHP
programming language, created by Marcus Baker, Jason Sweat, Travis Swicegood,
Perrick Penet and Edward Z. Yang.

Copyright (c) 2009 Piotr Roszatycki E<lt>dexter@debian.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under GNU Lesser General Public License.
