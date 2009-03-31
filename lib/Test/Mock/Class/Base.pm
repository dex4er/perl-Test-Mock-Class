#!/usr/bin/perl -c

package Test::Mock::Class::Base;

=head1 NAME

Test::Mock::Class::Base - Base class for mocked class

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

use Moose;


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

=item _mock_emulate_call(I<method> : Str, I<timing> : Int, I<args> : Array)

Finds the return value matching the incoming arguments. If there is no
matching value found then an error is triggered.

=cut

sub _mock_emulate_call {
    my ($self, $method, $timing, @args) = @_;

    my ($matching, $action) = ('action', 'value');

    return unless defined $self->_mock_attribute->{$matching}{$method};

    return $self->_mock_method_matching(
        $matching, $action, $method, $timing, @args
    );
};


=item _mock_check_expectations(I<method> : Str, I<timing> : Num, I<args> : Array)

Tests the arguments against expectations.

=cut

sub _mock_check_expectations {
    my ($self, $method, $timing, @args) = @_;

    my ($matching, $action) = ('expectation', 'assertion');

    return unless defined $self->_mock_attribute->{$matching}{$method};

    $self->_mock_method_matching(
        $matching, $action, $method, $timing, @args
    ) or fail(['Wrong arguments for method (%s) at call (%d)', $method, $timing]);
};


=item _mock_method_matching(I<matchings> : ArrayRef, I<action> : Str, I<method> : Str, I<timing> : Num, I<args> : Array)

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
            for (my $i=0; $i < @rule_args; $i++) {
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

        if (not defined $rule->{$action}) {
            return undef;
        }
        elsif (ref $rule->{$action} eq 'CODE') {
            return $rule->{$action}->($method, $timing, @args);
        }
        else {
            return $rule->{$action};
        };
    };
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

    push @{ $self->_mock_attribute->{action}{$method} } => \%params;

    return $self;
};


=item mock_expect( I<method> : Str, :I<at> : Int, :I<args> : ArrayRef[Any] ) : Self

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
        assertion => TRUE,
    };

    return $self;    
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

    push @{ $self->_mock_attribute->{action}{$method} } => {
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
