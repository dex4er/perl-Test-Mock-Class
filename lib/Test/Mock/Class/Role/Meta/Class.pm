#!/usr/bin/perl -c

package Test::Mock::Class::Role::Meta::Class;

=head1 NAME

Test::Mock::Class::Role::Meta::Class - Metaclass for mock class

=head1 DESCRIPTION

This role provides an API for defining and changing behavior of mock class.

=cut

use 5.006;

use strict;
use warnings;

our $VERSION = '0.01';

use Moose::Role;


use Class::Inspector;
use Symbol ();

use Test::Assert ':all';


=head1 ATTRIBUTE

=over

=item _mock_call : HashRef

Count of method calls stored as HashRef.

=cut

has '_mock_call' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
);


=item _mock_expectation : HashRef

Expectations for mock methods stored as HashRef.

=cut

has '_mock_expectation' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
);


=item _mock_return : HashRef

Return values or actions for mock methods stored as HashRef.

=back

=cut

has '_mock_return' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
);


use namespace::clean -except => 'meta';


## no critic RequireCheckingReturnValueOfEval

=head1 CONSTRUCTORS

=over

=item create_mock_class(I<name> : Str, :I<class> : Str, I<args> : Hash) : Moose::Meta::Class

Creates new L<Moose::Meta::Class> object which represents named mock class.
The method takes additional arguments:

=over

=item class

Optional L<class> parameter is a name of original class and its methods will
be created for new mock class.

=item methods

List of additional methods to create.

=back

The constructor returns metaclass object.

  Test::Mock::Class->create_mock_class(
      'IO::File::Mock' => ( class => 'IO::File' )
  );

=cut

sub create_mock_class {
    my ($class, $name, %args) = @_;
    my $self = $class->create($name, %args);
    $self = $self->_mock_reinitialize(%args);
    $self->_construct_mock_class(%args);
    return $self;
};


=item create_mock_anon_class(:I<class> : Str, I<args> : Hash) : Moose::Meta::Class

Creates new L<Moose::Meta::Class> object which represents anonymous mock
class.  Optional L<class> parameter is a name of original class and its
methods will be created for new mock class.

Anonymous classes are destroyed once the metaclass they are attached to goes
out of scope.

The constructor returns metaclass object.

  my $meta = Test::Mock::Class->create_mock_anon_class(
      class => 'File::Temp'
  );

=back

=cut

sub create_mock_anon_class {
    my ($class, %args) = @_;
    my $self = $class->create_anon_class;
    $self = $self->_mock_reinitialize(%args);
    $self->_construct_mock_class(%args);
    return $self;
};


=head1 METHODS

=over

=item add_mock_method(I<method> : Str) : Self

Adds new I<method> to mock class.  The behavior of this method can be changed
with C<add_mock_return_value> and other calls.

=cut

sub add_mock_method {
    my ($self, $method) = @_;
    $self->add_method( $method => sub {
        my $method_self = shift;
        return $method_self->meta->mock_invoke($method, @_);
    } );
    return $self;
};


=item add_mock_constructor(I<method> : Str) : Self

Adds new constructor to mock class.  This is almost the same as
C<add_mock_method> but it returns new object rather than defined value.

The calls counter is set to C<1> for new object's constructor.

=cut

sub add_mock_constructor {
    my ($self, $constructor) = @_;
    $self->add_method( $constructor => sub {
        my $method_class = shift;
        $method_class->meta->mock_invoke($constructor, @_) if blessed $method_class;
        my $new_object = $method_class->meta->new_object(@_);
        $new_object->meta->mock_invoke($constructor, @_);
        return $new_object;
    } );
    return $self;
};


=item mock_tally(I<>) : Self

Check the expectations at the end.  It should be called expicitly if
C<minimum> or C<count> parameter was used for expectation, or following
methods was called: C<add_mock_expectation_at_least_once>,
C<add_mock_expectation_call_count>, C<add_mock_expectation_minimum_call_count>
or C<add_mock_expectation_once>.

=cut

sub mock_tally {
    my ($self) = @_;

    my $expectation = $self->_mock_expectation;

    return if not defined $expectation
              or (ref $expectation || '') ne 'HASH';

    foreach my $method (keys %{ $expectation }) {
        next if not defined $expectation->{$method}
                or (ref $expectation->{$method} || '') ne 'ARRAY';

        foreach my $rule (@{ $expectation->{$method} }) {
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


=item mock_invoke(I<method> : Str, I<args> : Array) : Any

Returns the expected value for the method name and checks expectations.  Will
generate any test assertions as a result of expectations if there is a test
present.

This method is called in overridden methods of mock class, but you need to
call it manually if you construct own method.

=cut

sub mock_invoke {
    my ($self, $method, @args) = @_;

    assert_not_null($method) if ASSERT;

    my $timing = $self->_mock_add_call($method, @args);
    $self->_mock_check_expectations($method, $timing, @args);
    return $self->_mock_emulate_call($method, $timing, @args);
};


=item add_mock_return_value(I<method> : Str, I<value> : Any, :I<at> : Int, :I<args> : ArrayRef[Any]) : Self

Sets a return for a parameter list that will be passed on by call to this
method that match.

The first value is returned if more than one parameter list matches method's
arguments.  The C<undef> value is returned if none of parameters matches.

=over

=item method

Method name.

=item value

Returned value.

  $m->add_mock_return_value( 'open', 1 );

If value is coderef, then it is called with method name, current timing
and original arguments as arguments.

  $m->add_mock_return_value( 'sequence', sub {
      qw{one two three}[ $_[1] ]
  } );

=item at

Value is returned only for current timing, started from C<0>.

  $m->add_mock_return_value( 'sequence', 'one',   at => 0 );
  $m->add_mock_return_value( 'sequence', 'two',   at => 1 );
  $m->add_mock_return_value( 'sequence', 'three', at => 2 );

=item args

Value is returned only if method is called with proper argument.

  $m->add_mock_return_value(
      'get_value', 'admin', args => ['dbuser'],
  );
  $m->add_mock_return_value(
      'get_value', 'secret', args => ['dbpass'],
  );
  $m->add_mock_return_value(
      'get_value', sub { $_[2] }, args => [qr/.*/],
  );

=back

=cut

sub add_mock_return_value {
    my ($self, $method, $value, %params) = @_;

    $self->throw_error(
        'Usage: $mock->meta->add_mock_return_value( METHOD => VALUE, PARAMS )'
    ) unless defined $method;

    assert_equals('HASH', ref $self->_mock_return) if ASSERT;
    push @{ $self->_mock_return->{$method} } => { %params, value => $value };

    return $self;
};


=item add_mock_return_value_at(I<at> : Int, I<method> : Str, I<value> : Any, :I<args> : ArrayRef[Any]) : Self

Convenience method for returning a value upon the method call.

=cut

sub add_mock_return_value_at {
    my ($self, $at, $method, $value, %params) = @_;

    $self->throw_error(
        message => 'Usage: $mock->meta->add_mock_return_value_at( AT, METHOD => VALUE, PARAMS )'
    ) unless defined $at and defined $method;

    return $self->add_mock_return_value( $method => $value, %params, at => $at );
};


=item add_mock_exception(I<method> : Str, :I<at> : Int, I<exception> : Str|Object, :I<args> : ArrayRef[Any], I<params> : Hash) : Self

Sets up a trigger to throw an exception upon the method call.  The method
takes the same arguments as C<add_mock_return_value>.

If an I<exception> parameter is a string, the L<Exception::Assertion> is
thrown with this parameter as its message and rest of parameters as its
arguments.  If an I<exception> parameter is an object reference, the C<throw>
method is called on this object with predefined message and rest of parameters
as its arguments.

=cut

sub add_mock_exception {
    my ($self, $method, $exception, %params) = @_;

    Exception::Argument->throw(
        message => 'Usage: $mock->meta->add_mock_exception( METHOD => EXCEPTION, PARAMS )'
    ) unless defined $method;

    $exception = Exception::Assertion->new(
        message => $exception,
        reason  => ['Thrown on method (%s)', $method],
        %params
    ) unless blessed $exception;

    assert_equals('HASH', ref $self->_mock_return) if ASSERT;
    push @{ $self->_mock_return->{$method} } => {
        %params,
        value => sub {
            $exception->throw;
        },
    };

    return $self;
};


=item add_mock_exception_at(I<at> : Int, I<method> : Str, I<exception> : Str|Object, :I<args> : ArrayRef[Any]) : Self

Convenience method for throwing an error upon the method call.

=cut

sub add_mock_exception_at {
    my ($self, $at, $method, $exception, %params) = @_;

    Exception::Argument->throw(
        message => 'Usage: $mock->meta->add_mock_exception_at( AT, METHOD => EXCEPTION, PARAMS )'
    ) unless defined $at and defined $method;

    return $self->add_mock_exception( $method => $exception, %params, at => $at );
};


=item add_mock_expectation(I<method> : Str, :I<at> : Int, :I<minimum> : Int, :I<maximum> : Int, :I<count> : Int, :I<args> : ArrayRef[Any]) : Self

Sets up an expected call with a set of expected parameters in that call. All
calls will be compared to these expectations regardless of when the call is
made.  The method takes the same arguments as C<add_mock_return_value>.

=cut

sub add_mock_expectation {
    my ($self, $method, %params) = @_;

    Exception::Argument->throw(
        message => 'Usage: $mock->meta->add_mock_expectation( METHOD => PARAMS )'
    ) unless defined $method;

    assert_equals('HASH', ref $self->_mock_expectation) if ASSERT;
    push @{ $self->_mock_expectation->{$method} } => {
        %params,
    };

    return $self;
};


=item add_mock_expectation_at(I<at> : Int, I<method> : Str, :I<args> : ArrayRef[Any]) : Self

Sets up an expected call with a set of expected parameters in that call.

=cut

sub add_mock_expectation_at {
    my ($self, $at, $method, %params) = @_;

    Exception::Argument->throw(
        message => 'Usage: $mock->meta->add_mock_expectation_at( AT, METHOD => PARAMS )'
    ) unless defined $at and defined $method;

    return $self->add_mock_expectation( $method => %params, at => $at );
};


=item add_mock_expectation_call_count(I<method> : Str, I<count> : Int, :I<args> : ArrayRef[Any]) : Self

Sets an expectation for the number of times a method will be called. The
C<mock_tally> method have to be used to check this.

=cut

sub add_mock_expectation_call_count {
    my ($self, $method, $count, %params) = @_;

    Exception::Argument->throw(
        message => 'Usage: $mock->meta->add_mock_expectation_call_count( METHOD, COUNT => PARAMS )'
    ) unless defined $method and defined $count;

    return $self->add_mock_expectation( $method => %params, count => $count );
};


=item add_mock_expectation_maximum_call_count(I<method> : Str, I<count> : Int, :I<args> : ArrayRef[Any]) : Self

Sets the number of times a method may be called before a test failure is
triggered.

=cut

sub add_mock_expectation_maximum_call_count {
    my ($self, $method, $count, %params) = @_;

    Exception::Argument->throw(
        message => 'Usage: $mock->meta->add_mock_expectation_maximum_call_count( METHOD, COUNT => PARAMS )'
    ) unless defined $method and defined $count;

    return $self->add_mock_expectation( $method => %params, maximum => $count );
};


=item add_mock_expectation_minimum_call_count(I<method> : Str, I<count> : Int, :I<args> : ArrayRef[Any]) : Self

Sets the number of times to call a method to prevent a failure on the tally.

=cut

sub add_mock_expectation_minimum_call_count {
    my ($self, $method, $count, %params) = @_;

    Exception::Argument->throw(
        message => 'Usage: $mock->meta->add_mock_expectation_minimum_call_count( METHOD, COUNT => PARAMS )'
    ) unless defined $method and defined $count;

    return $self->add_mock_expectation( $method => %params, minimum => $count );
};


=item add_mock_expectation_never(I<method> : Str, :I<args> : ArrayRef[Any]) : Self

Convenience method for barring a method call.

=cut

sub add_mock_expectation_never {
    my ($self, $method, %params) = @_;

    Exception::Argument->throw(
        message => 'Usage: $mock->meta->add_mock_expectation_never( METHOD => PARAMS )'
    ) unless defined $method;

    return $self->add_mock_expectation( $method => %params, maximum => 0 );
};


=item add_mock_expectation_once(I<method> : Str, :I<args> : ArrayRef[Any]) : Self

Convenience method for a single method call.

=cut

sub add_mock_expectation_once {
    my ($self, $method, %params) = @_;

    Exception::Argument->throw(
        message => 'Usage: $mock->meta->add_mock_expectation_once( METHOD => PARAMS )'
    ) unless defined $method;

    return $self->add_mock_expectation( $method => %params, count => 1 );
};


=item add_mock_expectation_at_least_once(I<method> : Str, :I<args> : ArrayRef[Any]) : Self

Convenience method for requiring a method call.

=cut

sub add_mock_expectation_at_least_once {
    my ($self, $method, %params) = @_;

    Exception::Argument->throw(
        message => 'Usage: $mock->meta->add_mock_expectation_at_least_once( METHOD => PARAMS )'
    ) unless defined $method;

    return $self->add_mock_expectation( $method => %params, minimum => 1 );
};


=item _mock_reinitialize(:I<class> : Str) : Self

Reinitializes own metaclass with parameters taken from original I<class>.  It
is necessary if original class has changed C<attribute_metaclass>,
C<instance_metaclass> or C<method_metaclass>.

The method returns new metaclass object.

=cut

sub _mock_reinitialize {
    my ($self, %args) = @_;

    if (defined $args{class}) {
        Class::MOP::load_class($args{class});
        if (my %metaclasses = $self->_get_mock_metaclasses($args{class})) {
            my $new_meta = $args{class}->meta;
            my $new_self = $self->reinitialize(
                $self->name,
                %metaclasses,
            );

            $new_self->$_( $new_meta->$_ )
                foreach qw{constructor_class destructor_class error_class};

            %$self = %$new_self;
            bless $self, ref $new_self;

            Class::MOP::store_metaclass_by_name( $self->name, $self );
            Class::MOP::weaken_metaclass( $self->name ) if $self->is_anon_class;
        };
    };

    return $self;
};


=item _construct_mock_class(:I<class> : Str, :I<methods> : ArrayRef) : Self

Constructs mock class based on original class.  Adds the same methods as in
original class.  If original class has C<new> method, the constructor with
this name is created.

=cut

sub _construct_mock_class {
    my ($self, %args) = @_;

    if (defined $args{class}) {
        $self->superclasses(
            $self->_get_mock_superclasses($args{class}),
       );
    };

    my @methods = defined $args{methods} ? @{ $args{methods} } : ();

    my @mock_methods = do {
        my %uniq = map { $_ => 1 }
                   (
                       $self->_get_mock_methods($args{class}),
                       @methods,
                   );
        keys %uniq;
    };

    foreach my $method (@mock_methods) {
        next if $method eq 'meta';
        if ($method =~ /^(DEMOLISHALL|DESTROY)$/) {
            # ignore destructor
        }
        elsif ($method eq 'new') {
            $self->add_mock_constructor($method);
        }
        else {
            $self->add_mock_method($method);
        };
    };

    return $self;
};


sub _get_mock_methods {
    my ($self, $class) = @_;

    if ($class->can('meta')) {
        return $class->meta->get_all_method_names;
    };

    my $methods = Class::Inspector->methods($class);
    return defined $methods ? @$methods : ();
};


sub _get_mock_superclasses {
    my ($self, $class) = @_;

    return $class->can('meta')
           ? $class->meta->superclasses
           : @{ *{Symbol::qualify_to_ref($class . '::ISA')} };
};


sub _get_mock_metaclasses {
    my ($self, $class) = @_;

    return () unless defined $class;
    return () unless $class->can('meta');

    return (
        attribute_metaclass => $class->meta->attribute_metaclass,
        instance_metaclass  => $class->meta->instance_metaclass,
        method_metaclass    => $class->meta->method_metaclass,
    );
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


=item _mock_emulate_call(I<method> : Str, I<timing> : Int, I<args> : Array) : Any

Finds the return value matching the incoming arguments.  If there is no
matching value found then an error is triggered.

=cut

sub _mock_emulate_call {
    my ($self, $method, $timing, @args) = @_;

    assert_not_null($method) if ASSERT;
    assert_not_null($timing) if ASSERT;

    return $self->_mock_method_matching(
        attribute => '_mock_return',
        action    => 'value',
        method    => $method,
        timing    => $timing,
        args      => \@args,
    );
};


=item _mock_add_call(I<method> : Str, I<args> : Array) : Int

Adds one to the call count of a method and returns previous value.

=cut

sub _mock_add_call {
    my ($self, $method, @args) = @_;

    assert_not_null($method) if ASSERT;

    assert_equals('HASH', ref $self->call) if ASSERT;
    return $self->_mock_call->{$method}++;
};

=item _mock_check_expectations(I<method> : Str, I<timing> : Num, I<args> : Array) : Self

Tests the arguments against expectations.

=cut

sub _mock_check_expectations {
    my ($self, $method, $timing, @args) = @_;

    assert_not_null($method) if ASSERT;
    assert_not_null($timing) if ASSERT;

    return $self->_mock_method_matching(
        attribute => '_mock_expectation',
        action    => 'assertion',
        method    => $method,
        timing    => $timing,
        args      => \@args,
    );
};


=item _mock_method_matching(I<attribute> : Str, I<action> : Str, I<method> : Str, I<timing> : Num, I<args> : Array) : Any

Do matching for method and do some action if succeed.

This private method is shared between C<_mock_emulate_call> and
C<_mock_check_expectations> methods.

=over

=item attribute

Name of metaclass'es attribute which contains matching.

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
    my ($self, %args) = @_;

    assert_not_null($args{method}) if ASSERT;
    assert_not_null($args{attribute}) if ASSERT;
    assert_equals('ARRAY', $args{args}) if ASSERT;

    my $attribute = $args{attribute};
    my $attribute_for_method = $self->$attribute->{$args{method}};

    return if not defined $attribute_for_method
              or (ref $attribute_for_method || '') ne 'ARRAY';

    RULE:
    foreach my $rule (@$attribute_for_method) {
        if (defined $rule->{at}) {
            next unless $args{timing} == $rule->{at};
        };

        if (exists $rule->{args}) {
            my @rule_args = (ref $rule->{args} || '') eq 'ARRAY'
                            ? @{ $rule->{args} }
                            : ( $rule->{args} );

            # number of args matches?
            next unless @{$args{args}} == @rule_args;

            # iterate args
            foreach my $i (0 .. @rule_args - 1) {
                my $rule_arg = $rule_args[$i];
                if ((ref $rule_arg || '') eq 'Regexp') {
                    next RULE unless $args{args}->[$i] =~ $rule_arg;
                }
                elsif (ref $rule_arg) {
                    # TODO: use Test::Deep::NoTest
                    eval {
                        assert_deep_equals($args{args}->[$i], $rule_arg);
                    };
                    next RULE if $@;
                }
                else {
                    # TODO: do not use eval
                    eval {
                        assert_equals($args{args}->[$i], $rule_arg);
                    };
                    next RULE if $@;
                };
            };
        };

        $rule->{call} ++;

        fail([
            'Maximum call count (%d) for method (%s) at call (%d)',
            $rule->{maximum}, $args{method}, $args{timing}
        ]) if (defined $rule->{maximum} and $rule->{call} > $rule->{maximum});

        if (ref $rule->{$args{action}} eq 'CODE') {
            return $rule->{$args{action}}->(
                $args{method}, $args{timing}, @{$args{args}}
            );
        }
        elsif (defined $rule->{$args{action}}) {
            return $rule->{$args{action}};
        };
    };

    fail([
        'Wrong arguments for method (%s) at call (%d)',
        $args{method}, $args{timing}
    ]) if $args{attribute} eq '_mock_expectation';

    return;
};


1;


=back

=begin umlwiki

= Class Diagram =

[                                   <<role>>
                        Test::Mock::Class::Role::Meta::Class
 -----------------------------------------------------------------------------
 #_mock_call : HashRef
 #_mock_expectation : HashRef
 #_mock_return : HashRef
 -----------------------------------------------------------------------------
 +add_mock_return_value( I<method> : Str, :I<value> : Any, :I<at> : Int, :I<args> : ArrayRef[Any] ) : Self
 +add_mock_return_value_at( I<at> : Int, I<method> : Str, :I<args> : ArrayRef[Any] ) : Self
 +add_mock_exception( I<method> : Str, :I<at> : Int, :I<exception> : Str, :I<args> : ArrayRef[Any] ) : Self
 +add_mock_exception_at( I<at> : Int, I<method> : Str, :I<args> : ArrayRef[Any] ) : Self
 +add_mock_expectation( I<method> : Str, :I<at> : Int, :I<minimum> : Int, :I<maximum> : Int, :I<count> : Int, :I<args> : ArrayRef[Any] ) : Self
 +add_mock_expectation_at( I<at> : Int, I<method> : Str, :I<args> : ArrayRef[Any] ) : Self
 +add_mock_expectation_call_count( I<method> : Str, I<count> : Int, :I<args> : ArrayRef[Any] ) : Self
 +add_mock_expectation_maximum_call_count( I<method> : Str, I<count> : Int, :I<args> : ArrayRef[Any] ) : Self
 +add_mock_expectation_minimum_call_count( I<method> : Str, I<count> : Int, :I<args> : ArrayRef[Any] ) : Self
 +add_mock_expectation_never( I<method> : Str, :I<args> : ArrayRef[Any] ) : Self
 +add_mock_expectation_once( I<method> : Str, :I<args> : ArrayRef[Any] ) : Self
 +add_mock_expectation_at_least_once( I<method> : Str, :I<args> : ArrayRef[Any] ) : Self
 +mock_tally() : Self
                                                                              ]

=end umlwiki

=head1 SEE ALSO

L<Test::Mock::Class>.

=head1 BUGS

The API is not stable yet and can be changed in future.

=head1 AUTHOR

Piotr Roszatycki <dexter@cpan.org>

=head1 LICENSE

Based on SimpleTest, an open source unit test framework for the PHP
programming language, created by Marcus Baker, Jason Sweat, Travis Swicegood,
Perrick Penet and Edward Z. Yang.

Copyright (c) 2009 Piotr Roszatycki <dexter@cpan.org>.

This program is free software; you can redistribute it and/or modify it
under GNU Lesser General Public License.
