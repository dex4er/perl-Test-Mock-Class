#!/usr/bin/perl -c

package Test::Mock::Class;

=head1 NAME

Test::Mock::Class - Simulating other classes

=head1 SYNOPSIS

  use Test::Mock::Class ':all';
  mock_class 'Net::FTP' => 'Net::FTP::Mock';
  my $mock_object = Net::FTP::Mock->new;

  # anonymous mocked class
  my $generator = Test::Mock::Class->new( class => 'Net::FTP' );
  my $mock_class = $generator->generate;
  my $mock_object = $mock_class->new;

=head1 DESCRIPTION

In a unit test, mock objects can simulate the behavior of complex, real
(non-mock) objects and are therefore useful when a real object is impractical
or impossible to incorporate into a unit test.

The unique features of C<Test::Mock::Class>:

=over

=item *

It's API is inspired by PHP SimpleTest framework.

=item *

It isn't tied with L<Test::Builder> so it can be used standalone or with
xUnit-like framework, i.e. L<Test::Unit::Lite>.

=item *

The mock classes are C<Class::MOP> based so they're easly expandable and have
introspection capability.

=item *

Mocks as actors: The mock version of a class has all the methods of the
original class.  The return value will be C<undef>, but it can be changed with
C<mock_returns> method.

=item *

Mocks as critics: The method of mock version of a class can check its calling
arguments and throws an exception if arguments don't match (C<mock_expect>
method).  An exception also can be thrown if the method wasn't called at all
(C<mock_expect_once> method).

=back

All mock classes have L<Test::Mock::Class::Base> as their base class.  This
class provides API for extending mock classes and adding special assertions.

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

use Exception::Base 'Test::Mock::Class::Exception';

use Test::Mock::Class::Base;
use Test::Mock::Class::Inspector;


use constant {
    Base      => 'Test::Mock::Class::Base',
    Exception => 'Test::Mock::Class::Exception',
    Inspector => 'Test::Mock::Class::Inspector',
};


=head1 ATTRIBUTES

=over

=item class : Str

Class to clone.

=cut

has 'class' => (
    is        => 'ro',
    isa       => 'Str',
    predicate => 'has_class',
);

=item mock_class : Str

New class name.

=cut

has 'mock_class' => (
    is        => 'ro',
    isa       => 'Str',
    writer    => '_set_mock_class',
    predicate => 'has_mock_class',
);

=item mock_metaclass : Moose::Meta::Class

Metaclass for mock class.

=cut

has 'mock_metaclass' => (
    is        => 'ro',
    writer    => '_set_mock_metaclass',
);

=item methods : ArrayRef[Str]

List of methods which are created for mock class.

=cut

has 'methods' => (
    is        => 'ro',
    isa       => 'ArrayRef[Str]',
    predicate => 'has_methods',
);

=item mock_base : Str

Base mock class name.

=cut

has 'mock_base' => (
    is      => 'ro',
    isa     => 'Str',
    default => Base,
);

=item inspector : Test::Mock::Class::Inspector

Reflection API for class.

=cut

has 'inspector' => (
    is      => 'ro',
    isa     => Inspector,
    lazy    => TRUE,
    default => sub {
        Inspector->new( class => $_[0]->class )
    },
);

=item mock_inspector : Test::Mock::Class::Inspector

Reflection API for mock class.

=back

=cut

has 'mock_inspector' => (
    is      => 'ro',
    isa     => Inspector,
    lazy    => TRUE,
    default => sub {
        Inspector->new( class => $_[0]->mock_class )
    },
);


use namespace::clean -except => 'meta';


=head1 FUNCTIONS

=over

=cut

BEGIN {
    my %exports = ();

=item mock_class(I<class> : Str, I<mock_class> : Str = undef) : Str

Creates mock class based on original I<class>.  If the name of I<mock_class>
is undefined, its name is created based on name of original I<class> with
added C<::Mock> suffix.

The function returns the name of new I<mock_class>.

=back

=cut

    $exports{mock_class} = sub {
        sub ($;$) {
            my $generator = __PACKAGE__->new(
                class => $_[0],
                mock_class => defined $_[1] ? $_[1] : $_[0] . '::Mock',
            );
            return $generator->generate;  
        };  
    };

=head1 IMPORTS

=over

=cut

    my %groups = ();

=item Test::Mock::Class ':all';

Imports all functions into caller's namespace.

=back

=cut

    $groups{all} = [ keys %exports ];

    require Sub::Exporter;
    Sub::Exporter->import(
        -setup => {
            exports => [ %exports ],
            groups => \%groups,
        },
    );
};


=head1 METHODS

=over

=item generate(I<>) : ClassName

Clones an interface of original class and creates a mock version that can have
return values and expectations set.

The method returns a class name of mock version.

=back

=cut

sub generate {
    my ($self) = @_;

    if ($self->has_class) {
        Exception->throw(
            message => [ 'Class %s does not exist', $self->class ],
        ) unless $self->inspector->class_exists;
    };
    
    if ($self->has_mock_class) {
        Exception->throw(
            message => [ 'Class %s already exists', $self->mock_class ],
        ) if $self->mock_inspector->class_exists_sans_autoload;
    };

    $self->_create_class;

    return $self->mock_class;
};


sub _create_class {
    my ($self) = @_;

    my @methods = $self->has_methods ? @{ $self->methods } : ();

    my @mock_methods = do {
        my %uniq = map { $_ => 1 }
                   ($self->inspector->get_methods, @methods, 'new');
        keys %uniq;
    };

    my $metaclass;
    if ($self->has_mock_class) {
        $metaclass = Moose::Meta::Class->create($self->mock_class);
    }
    else {
        $metaclass = Moose::Meta::Class->create_anon_class;
        $self->_set_mock_class($metaclass->name);
    };

    $self->_set_mock_metaclass($metaclass);

    my @metaclass_instance_roles = $self->inspector->get_metaclass_instance_roles;
    if (@metaclass_instance_roles) {
        Moose::Util::MetaRole::apply_metaclass_roles(
            for_class => $self->mock_class,
            instance_metaclass_roles => \@metaclass_instance_roles,
        );  
    };

    $metaclass->superclasses(Base, $self->inspector->get_superclasses);

    foreach my $method (@mock_methods) {
        next if $method eq 'meta';
        if ($method eq 'new') {
            $self->mock_class->mock_add_constructor($method);
        }
        else {
            $self->mock_class->mock_add_method($method);
        };
    };

    return $self;
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
