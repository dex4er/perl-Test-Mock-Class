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

extends 'Moose::Meta::Class';
with 'Test::Mock::Class::Role::Meta::Class';


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
            return Test::Mock::Class->create_mock_class(
                defined $_[1] ? $_[1] : $_[0] . '::Mock',
                class => $_[0],
            );
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
