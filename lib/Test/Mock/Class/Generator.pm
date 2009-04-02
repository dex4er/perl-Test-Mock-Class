#!/usr/bin/perl -c

package Test::Mock::Class::Generator;

=head1 NAME

Test::Mock::Class::Generator - Code generation of mock objects

=head1 SYNOPSIS

  use Test::Mock::Class::Generator;

  # generate mock class which mimics existsing class
  Test::Mock::Class::Generator->new(
      class => 'Net::FTP',
      mock_class => 'Net::FTP::Mock',
  )->generate;

  # generate mock class with only one method overridden 
  Test::Mock::Class::Generator->generate(
      class => 'File::Stat::Moose',
      mock_class => 'File::Stat:Moose::Mock',
  )->generate('stat');

  # generate new empty mock class with some new methods
  Test::Mock::Class::Generator->generate(
      mock_class => 'My::Handler::Mock',
  )->generate('start_tag', 'end_tag');

  # create new mock object
  my $obj = Test::Mock::Class::Generator->new(
      class => 'IO::File',
  )->generate->new; 

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
    default => Base,
);

=item reflection : Test::Mock::Class::Reflection

Reflection API for class.

=back

=cut

has 'inspector' => (
    is      => 'ro',
    isa     => Inspector,
    default => sub {
        Inspector->new( class => $_[0]->class )
    },
);


use namespace::clean -except => 'meta';


=head1 METHODS

=over

=item generate(I<methods> : Array = ()) : Str

Clones a class' interface and creates a mock version that can have return
values and expectations set.

=over

=item I<methods>

Additional methods to add beyond those in the cloned class. Use this to
emulate the dynamic addition of methods in the cloned class or when the
class hasn't been written yet.

=back

=cut

sub generate {
    my ($self, @methods) = @_;

    Exception->throw(
        message => [ 'Class %s does not exist', $self->class ],
    ) unless $self->inspector->class_exists;

    my $mock_inspector = Inspector->new( class => $_[0]->mock_class );
    Exception->throw(
        message => [ 'Class %s already exists', $self->mock_class ],
    ) if $mock_inspector->class_exists_sans_autoload;

    my $meta = $self->_create_class(@methods);
    return $meta->name;
};


=item _create_class(I<methods> : Array) : Moose::Meta::Class

The new mock class code as a string.

=over

=item I<methods>

Additional methods to create.

=back

=cut

sub _create_class {
    my ($self, @methods) = @_;

    my @mock_methods = do {
        my %uniq = map { $_ => 1 }
                   ($self->inspector->get_methods, @methods, 'new');
        keys %uniq;
    };

    my $metaclass = Moose::Meta::Class->create($self->mock_class);
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
