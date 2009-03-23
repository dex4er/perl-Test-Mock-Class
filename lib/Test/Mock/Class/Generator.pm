#!/usr/bin/perl -c

package Test::Mock::Class::Generator;

=head1 NAME

Test::Mock::Class::Generator - Code generation of mock objects

=head1 SYNOPSIS

  use Test::Mock::Class::Generator;

=head1 DESCRIPTION

Service class for code generation of mock objects.

=for readme stop

=cut

use 5.006;

use strict;
use warnings;

our $VERSION = '0.01';

use Moose;


use constant::boolean;

use Class::MOP;
use Moose::Meta::Class;


=head1 ATTRIBUTES

=over

=item class : Str

Class to clone.

=cut

has 'class' => (
    is  => 'ro',
    isa => 'Str',
);

=item mock_class : Str

New class name.

=cut

has 'mock_class' => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub { $_[0]->class . '::Mock' },
);

=item mock_base : Str

Base mock class name.

=cut

has 'mock_base' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'Test::Mock::Class::Base',
);

=item reflection : Test::Mock::Class::Reflection

Reflection API for class.

=back

=cut

has 'reflection' => (
    is      => 'ro',
    isa     => 'Test::Mock::Class::Reflection',
    default => sub {
        Test::Mock::Class::Reflection->new( class => $_[0]->class )
    },
);


use namespace::clean -except => 'meta';


=head1 METHODS

=over

=item generate(I<methods> : Array = ()) : Bool

Clones a class' interface and creates a mock version that can have return
values and expectations set.

=over

=item I<methods>

Additional methods to add beyond those in th cloned class. Use this to
emulate the dynamic addition of methods in the cloned class or when the
class hasn't been written yet.

=back

=cut

sub generate {
    my ($self, @methods) = @_;

    return FALSE unless Class::MOP::is_class_loaded($self->class);
    return FALSE if Class::MOP::is_class_loaded($self->mock_class);
    return !! $self->_create_class(@methods);
};


=item _create_class(I<methods> : Array) : Moose::Meta::Class

The new mock class code as a string.

=over

=item I<methods>

Additional methods to create

=back

=cut

sub _create_class {
    my ($self, @methods) = @_;
    my $metaclass = Moose::Meta::Class->create($self->mock_class);
    if ($self->class->can('meta')) {
        @superclasses = $self->class->meta->superclasses;
    }
    else {
        @superclasses =   
    };
    return $metaclass;
};

1;


=back

=begin umlwiki

= Class Diagram =

[                          <<utility>>
                        Test::Mock::Class
 -----------------------------------------------------------------------
 -----------------------------------------------------------------------
 mock_class(class : Str, mock_class : Str = undef, methods : Array = ())
 mock_class_partial(class : Str, mock_class : Str, methods : Array)
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
