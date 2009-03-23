#!/usr/bin/perl -c

package Test::Mock::Class::Reflection;

=head1 NAME

Test::Mock::Class::Reflection - Reflection API

=head1 SYNOPSIS

  use Test::Mock::Class::Reflection;
  my $reflection = Test::Mock::Class::Reflection->new(  
      class => 'Net::FTP'
  );
  print $reflection->class_exists;

=head1 DESCRIPTION

Reflection API.

=for readme stop

=cut

use 5.006;

use strict;
use warnings;

our $VERSION = '0.01';

use Moose;


use Class::MOP;
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

Checks that a class has been declared.

=cut

sub class_exists {
    my ($self) = @_;
    return Class::MOP::is_class_loaded($self->class);
};


1;


=back

=begin umlwiki

= Class Diagram =

[                          <<utility>>
                    Test::Mock::Class::Reflection
 -----------------------------------------------------------------------
 -----------------------------------------------------------------------
 class_exists()
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
