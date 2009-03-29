#!/usr/bin/perl -c

package Test::Mock::Class::Inspector;

=head1 NAME

Test::Mock::Class::Inspector - Introspection for mock objects

=head1 SYNOPSIS

  use Test::Mock::Class::Inspector;
  my $inspector = Test::Mock::Class::Inspector->new(  
      class => 'Net::FTP'
  );
  print $inspector->class_exists;

=head1 DESCRIPTION

Reflection API.

=for readme stop

=cut

use 5.006;

use strict;
use warnings;

our $VERSION = '0.01';

use Moose;


use Symbol ();
use Class::MOP;
use Moose::Meta::Class;
use Class::Inspector;


=head1 ATTRIBUTES

=over

=item class : Str

Class to inspect.

=back

=cut

has 'class' => (
    is  => 'ro',
    isa => 'Str',
);


use namespace::clean -except => 'meta';


=head1 METHODS

=over

=item class_exists : Bool

Checks that a class does exist.  It loads it if not loaded yet.

=cut

sub class_exists {
    my ($self) = @_;
    eval {
        Class::MOP::load_class($self->class);
    };
    return Class::MOP::is_class_loaded($self->class);
};


=item class_exists_sans_autoload : Bool

Checks that a class does exist. Does not autoload the class.

=cut

sub class_exists_sans_autoload {
    my ($self) = @_;
    return Class::MOP::is_class_loaded($self->class);
};


=item get_parent

Finds the parent class name.

=cut

sub get_superclasses {
    my ($self) = @_;

    my @parent;

    if ($self->class->can('meta')) {
        @parent = $self->class->meta->superclasses;
    }
    else {
        @parent = @{ *{Symbol::qualify_to_ref($self->class . '::ISA')} };
    };

    return @parent;
};

sub get_metaclass_instance_roles {
    my ($self) = @_;
    
    return () unless $self->class->can('meta');

    my $metaclass_instance = $self->class->meta->get_meta_instance->meta;
    
    return () unless $metaclass_instance->can('roles');

    return map { $_->name }
           @{ $metaclass_instance->roles };
};


=item get_methods

Gets the list of methods on a class, including superclasses.

=cut

sub get_methods {
    my ($self) = @_;
      
    my @methods;

    if ($self->class->can('meta')) {
        @methods = $self->class->meta->get_all_method_names;
    }
    else {
        @methods = Class::Inspector->methods($self->class);
    };

    return @methods;
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
