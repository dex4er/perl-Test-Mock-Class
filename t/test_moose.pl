#!/usr/bin/perl

$ENV{ANY_MOOSE} = 'Moose';
do 'test.pl';
die $@ if $@;
