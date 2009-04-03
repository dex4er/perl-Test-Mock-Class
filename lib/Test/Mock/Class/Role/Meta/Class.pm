#!/usr/bin/perl -c

package Test::Mock::Class::Role::Meta::Class;

=head1 NAME

Test::Mock::Class::Role::Meta::Class - Simulating other classes

=head1 SYNOPSIS

...

=head1 DESCRIPTION

...

=cut

use 5.006;

use strict;
use warnings;

our $VERSION = '0.01';

use Moose::Role;


#use constant::boolean;
use Class::Inspector;
use Symbol;

use Test::Assert ':all';


=head1 ATTRIBUTE

=over

=item _mock_attribute : HashRef

The additional state of mock object is stored in this inside-out attribute. 

=back

=cut

has '_mock_attribute' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
);


#use namespace::clean -except => 'meta';


use Smart::Comments;


sub create_mock_class {
    my ($class, $name, %args) = @_;
    my $self = $class->create($name, %args);
    $self->_construct_mock_class(%args);
    return $self;
};


sub create_mock_anon_class {
    my ($class, %args) = @_;
    my $self = $class->create_anon_class;
    $self->_construct_mock_class(%args);
    return $self;
};


sub _construct_mock_class {
    my ($self, %args) = @_;

    if (defined $args{class}) {
        Class::MOP::load_class($args{class});
        $self->superclasses(
            $self->_get_mock_superclasses($args{class}),
        );
    };

    my @metaclass_instance_roles = $self->_get_mock_metaclass_instance_roles($args{class});
## @metaclass_instance_roles
    if (@metaclass_instance_roles) {
        Moose::Util::MetaRole::apply_metaclass_roles(
            for_class => $self->name,
            instance_metaclass_roles => \@metaclass_instance_roles,
        );  
    };

    my @methods = defined $args{methods} ? @{ $args{methods} } : ();

    my @mock_methods = do {
        my %uniq = map { $_ => 1 }
                   (
                       $self->_get_mock_methods($args{class}),
                       @methods, 'new'
                   );
        keys %uniq;
    };

    foreach my $method (@mock_methods) {
        next if $method eq 'meta';
        if ($method eq 'new') {
            $self->add_mock_constructor($method);
        }
        else {
            $self->add_mock_method($method);
        };
    };

    return $self;
};


sub add_mock_method {
    my ($self, $method) = @_;
    $self->add_method( $method => sub {
        my $method_self = shift;
        return $method_self->meta->_mock_invoke($method, @_);
    } );
    return $self;
};


sub add_mock_constructor {
    my ($self, $constructor) = @_;
    $self->add_method( $constructor => sub {
        my $method_class = shift;
        $method_class->meta->_mock_invoke($constructor, @_) if blessed $method_class;
        my $method_self = $method_class->meta->new_object(@_);
        $method_self->meta->_mock_invoke($constructor, @_);
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

sub add_mock_return {
    ### add_mock_return: @_
    my ($self, $method, %params) = @_;

    $self->throw_error(
        'Usage: $mock->meta->add_mock_return( METHOD => PARAMS )'
    ) unless defined $method;

    push @{ $self->_mock_attribute->{return}{$method} } => \%params;

    return $self;
};


=item mock_returns_at( I<at> : Int, I<method> : Str, :I<args> : ArrayRef[Any] ) : Self

Convenience method for returning a value upon the method call.

=cut

sub add_mock_return_at {
    my ($self, $at, $method, %params) = @_;
    
    $self->throw_error(
        message => 'Usage: $mock->meta->add_mock_return_at( AT, METHOD => PARAMS )'
    ) unless defined $at and defined $method;

    return $self->add_mock_return( $method => %params, at => $at );
};


sub _get_mock_methods {
    my ($self, $class) = @_;

    return $class->can('meta')
           ? $class->meta->get_all_method_names
           : @{ Class::Inspector->methods($class) };
};


sub _get_mock_superclasses {
    my ($self, $class) = @_;

    return $class->can('meta')
           ? $class->meta->superclasses
           : @{ *{Symbol::qualify_to_ref($class . '::ISA')} };
};


sub _get_mock_metaclass_instance_roles {
    my ($self, $class) = @_;

    return () unless defined $class;    
    return () unless $class->can('meta');

    my $metaclass_instance = $class->meta->get_meta_instance->meta;
    
    return () unless $metaclass_instance->can('roles');

    return map { $_->name }
           @{ $metaclass_instance->roles };
};


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


=item _mock_add_call(I<method> : Str, I<args> : Array) : Int

Adds one to the call count of a method and returns current value.

=cut

sub _mock_add_call {
    my ($self, $method, @args) = @_;

    assert_not_null($method) if ASSERT;
    return ++$self->_mock_attribute->{call}{$method};
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


1;


=back

=begin umlwiki

= Class Diagram =

[                          <<utility>>
                        Test::Mock::Class
 -----------------------------------------------------------------------
 +class : Str
 +mock_class : Str
 +mock_metaclass : Moose::Meta::Class
 +methods : ArrayRef[Str]
 +mock_base : Str
 +inspector : Test::Mock::Class::Inspector
 +mock_inspector : Test::Mock::Class::Inspector
 -----------------------------------------------------------------------
 +generate() : ClassName
 mock_class(class : Str, mock_class : Str = undef, methods : Array = ())
 mock_class_partial(class : Str, mock_class : Str, methods : Array)
                                                                        ]

=end umlwiki

=head1 SEE ALSO

L<Test::MockObject>, L<Test::MockClass>.

=back

L<Moose::Meta::Class>.

=head1 BUGS

The API is not stable yet and can be changed in future.

=head1 TODO

=over

=item *

Support for L<Moose::Role> based classes.

=item *

Better documentation.

=item *

More tests.

=back

=for readme continue

=head1 AUTHOR

Piotr Roszatycki <dexter@cpan.org>

=head1 LICENSE

Based on SimpleTest, an open source unit test framework for the PHP
programming language, created by Marcus Baker, Jason Sweat, Travis Swicegood,
Perrick Penet and Edward Z. Yang.

Copyright (c) 2009 Piotr Roszatycki <dexter@cpan.org>.

This program is free software; you can redistribute it and/or modify it
under GNU Lesser General Public License.
