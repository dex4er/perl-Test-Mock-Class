#!/usr/bin/perl

$ENV{ANY_MOOSE} = 'Mouse';
do 'test.pl';
die $@ if $@;
