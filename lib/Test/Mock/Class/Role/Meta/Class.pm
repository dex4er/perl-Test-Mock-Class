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


use Moose::Util;

use Class::Inspector;
use Symbol ();

use Test::Assert ':all';


#use namespace::clean -except => 'meta';


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
        return $method_self->mock_invoke($method, @_);
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
        $method_class->mock_invoke($constructor, @_) if blessed $method_class;
        my $new_object = $method_class->meta->new_object(@_);
        $new_object->mock_invoke($constructor, @_);
        return $new_object;
    } );
    return $self;
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

    Moose::Util::apply_all_roles(
        $self,
        'Test::Mock::Class::Role::Object',
    );

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
        if ($method =~ /^(DEMOLISHALL|DESTROY|DOES|does|isa)$/) {
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


1;


=back

=begin umlwiki

= Class Diagram =

[                                    <<role>>
                        Test::Mock::Class::Role::Meta::Class
 ------------------------------------------------------------------------------
 ------------------------------------------------------------------------------
 +create_mock_class(name : Str, :class : Str, args : Hash) : Moose::Meta::Class
 +create_mock_anon_class(:class : Str, args : Hash) : Moose::Meta::Class
 +add_mock_method(method : Str) : Self
 +add_mock_constructor(method : Str) : Self
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
