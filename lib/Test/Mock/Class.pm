#!/usr/bin/perl -c

package Test::Mock::Class;

=head1 NAME

Test::Mock::Class - Simulating other classes

=head1 SYNOPSIS

  use Test::Mock::Class ':all';
  mock_class 'Net::FTP' => 'Mock::Net::FTP';

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


use English '-no_match_vars';


=head1 ATTRIBUTES

=over

=back

=cut


use namespace::clean -except => 'meta';


=head1 FUNCTIONS

=over

=item mock_class(I<class> : Str, I<mock_class> : Str = undef, I<methods> : ArrayRef = undef)

Clones a class' interface and creates a mock version that can have return
values and expectations set.

I<class> is a class to clone.

I<mock_class> is a new class name. Default is the old name with C<Mock::>
prepended.

I<methods> is an additional methods to add beyond those in the cloned class.
Use this to emulate the dynamic addition of methods in the cloned class or
when the class hasn't been written yet

=cut

sub mock_class {
    my ($class, $mock_class, $methods) = @_;
    my $generator = MockGenerator->new($class, $mock_class);
    return $generator->generateSubclass($methods);
};



=back

=cut


1;


=back

=begin umlwiki

= Class Diagram =

[Test::Mock::Class]

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
