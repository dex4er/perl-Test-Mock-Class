#!/usr/bin/perl -c

package Test::Mock::Class;

=head1 NAME

Test::Mock::Class - Simulating other classes

=head1 SYNOPSIS

  use Test::Mock::Class ':all';
  mock_class 'Net::FTP' => 'Net::FTP::Mock';

=head1 DESCRIPTION

In a unit test, mock objects can simulate the behavior of complex, real
(non-mock) objects and are therefore useful when a real object is impractical
or impossible to incorporate into a unit test.

=for readme stop

=cut

use 5.006;

use strict;
use warnings;

our $VERSION = '0.01';

use Moose;


use Test::Mock::Class::Generator;


use namespace::clean -except => 'meta';


=head1 METHODS

=over

=item generate(I<class> : Str, I<mock_class> : Str = undef, I<methods> : Array = ())

Clones a class' interface and creates a mock version that can have return
values and expectations set.

=over

=item I<class>

Class to clone.

=item I<mock_class>

New class name. Default is the old name with C<::Mock>
appended.

=item I<methods>

Additional methods to add beyond those in the cloned class.  Use this to
emulate the dynamic addition of methods in the cloned class or when the class
hasn't been written yet.

=back

=cut

sub generate {
    my ($self, $class, $mock_class, @methods) = @_;
    my $generator = Test::Mock::Class::Generator->new(
        class      => $class,
        defined $mock_class ? (mock_class => $mock_class) : (),
    );
    return $generator->generate_subclass(@methods);
};


=item mock_class_partial(I<class> : Str, I<mock_class> : Str, I<methods> : Array)

Generates a version of a class with selected methods mocked only.  Inherits
the old class and chains the mock methods of an aggregated mock object.

=over

=item I<class>

Class to clone.

=item I<mock_class>

New class name.

I<methods>

Methods to be overridden with mock versions.

=back

=cut

sub mock_class_partial {
    my ($self, $class, $mock_class, @methods) = @_;
    my $generator = Test::Mock::Class::Generator->new(
        class      => $class,
        mock_class => $mock_class
    );
    return $generator->generate_subclass_partial(@methods);
};


=back

=cut


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
