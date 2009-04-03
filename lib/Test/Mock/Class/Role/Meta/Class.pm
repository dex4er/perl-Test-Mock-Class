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


use constant::boolean;

use Smart::Comments;


sub create_mock_class {
### create_mock_class: @_
    my ($class, $name, %args) = @_;

    if (defined $args{class}) {    
        $class->throw_error("Class ($class) does not exist")
            unless $class->_does_class_exist($class);
        if (not $args{class}->can('meta')) {
            Moose::Meta::Class->initialize($args{class});  
        };
    };

    my @methods = defined $args{methods} ? @{ $args{methods} } : ();

    my @mock_methods = do {
        my %uniq = map { $_ => 1 }
                   (
                       defined $args{class} ? $args{class}->meta->get_all_method_names : (),
                       @methods, 'new'
                   );
        keys %uniq;
    };

    my $metaclass = defined $name
                    ? $class->create($name)
                    : $class->create_anon_class;

    my @metaclass_instance_roles = $class->_get_metaclass_instance_roles($args{class});
    if (@metaclass_instance_roles) {
        Moose::Util::MetaRole::apply_metaclass_roles(
            for_class => $metaclass->name,
            instance_metaclass_roles => \@metaclass_instance_roles,
        );  
    };

    $metaclass->superclasses(
        'Test::Mock::Class::Base',
        defined $args{class} ? $args{class}->meta->superclasses : (),
    );

    foreach my $method (@mock_methods) {
        next if $method eq 'meta';
        if ($method eq 'new') {
            $metaclass->add_mock_constructor($method);
        }
        else {
            $metaclass->add_mock_method($method);
        };
    };

    return $metaclass;
};


sub add_mock_method {
    my ($self, $method) = @_;
    $self->add_method( $method => sub {
        my $method_self = shift;
        return $method_self->_mock_invoke($method, @_);
    } );
    return $self;
};


sub add_mock_constructor {
    my ($self, $constructor) = @_;
    $self->add_method( $constructor => sub {
        my $method_class = shift;
        $method_class->_mock_invoke($constructor, @_) if blessed $method_class;
        my $method_self = $method_class->meta->new_object(@_);
        $method_self->_mock_invoke($constructor, @_);
        return $method_self;
    } );
    return $self;
};


sub _does_class_exist {
    my ($self, $class) = @_;
    eval {
        Class::MOP::load_class($class);
    };
    return $self->_is_class_loaded($class);
};


sub _is_class_loaded {
    my ($self, $class) = @_;
    return Class::MOP::is_class_loaded($class);
};


sub _get_metaclass_instance_roles {
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
