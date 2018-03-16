#!/usr/bin/env perl

# pragmae
use strict;
use warnings;

use feature qw(say);
use version; our $VERSION = qv('1.0.0');    # Because perlcritic insists

# modules
use Getopt::Long;
use English qw( -no_match_vars );

# This program will examine a list of data elements, one at a time and,
# using an algorithm from the Perl Cookbook, determine if that item should
# be returned as the selected item.
#
# Take a look at the generate subroutine for the implementation and the README
# for more explanation.

# Copyright 2014 Bob Simpson <bob@pobox.com>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

#========================================
# Program Options
#========================================

my $option = {
    'input' => 'quarks.txt',    # What's our input file?
    'sets'  => 50_000,          # How many sets are we going to do?
};

#<<< tidy off
GetOptions(
    $option,
    'input=s',
    'sets=i'
    ) or pod2usage;
#>>> tidy on

# How far off can the result be from 100% before we apply a visible tag
# in the output? ( 1 = 1% )
my $spread = 1;
$spread =
  $spread / 100;    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)

#========================================
# Setup
#========================================

# We need to know how many items we have in the list to make sure we're
# getting the right number of each in the results.
my $data = count_data( { file => $option{input} } );

# We'll multiply the number of sets by the number of elements so we
# don't get weird fractions that might skew the results.
my $loops = $option{sets} * $data;

#========================================
# Main body of work
#========================================

# Tell the user what we're doing.
say $data    ## no critic (RequireBracedFileHandleWithPrint)
  . ' data elements.'
  . " $option{sets} sets."
  . " $loops loops."
  . " $spread margin of error.";

say "\nWorking...";
say "Data from $option{input}";

# Keep track of our results for reporting.
my $result;

# For each loop get one random item.
foreach my $loop ( 1 .. $loops ) {
    my $item = generate( { file => $option{input} } );
    $result->{$item}->{count}++;

    # Report progress every now and then.
    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
    my $percent = 10;
    if ( !( $loop % int( $loops / ( 100 / $percent ) ) ) ) {
        say sprintf '%*s (%3d%%)', length $loops, $loop, $loop / $loops * 100;
    }
    ## use critic

}

# Tell folks what we found.
report_results( { results => $result } );

#========================================
# Subroutines
#========================================

# Used to make formatting nice.
sub count_data {
    my $args = shift;
    my $file = $args->{file};
    my $count;
    open my $fh, '<', $file or die "cannot open < $file: $OS_ERROR\n";
    while (<$fh>) { $count++; }
    close $fh or die "File handle close failed: $OS_ERROR\n";
    return $count;
}

# This function implements the algorithm from the Perl Cookbook.
# http://docstore.mik.ua/orelly/perl/cookbook/ch08_07.htm
#
# Assuming you don't want to load the whole data set into memory,
# this lets you go through the list one item at a time and determine
# if "this item" is the "right answer" (More explanation in the README)
sub generate {
    my $args = shift;
    my $file = $args->{file};

    # Housekeeping
    my $count;
    my $item;

    # Go through the input, one item at a time. Check to see if this
    # is the item we should return if this is the last item in the list.
    #
    # Note that the first time through, it is always true, giving
    # $item a specific initial value.
    open my $fh, '<', $file or die "cannot open [$file]: $OS_ERROR\n";
    while ( my $line = <$fh> ) {
        chomp $line;
        $count++;
        if ( rand $count < 1 ) { $item = $line; }
    }
    close $fh or die "close filehandle for [$file] failed: $OS_ERROR\n";
    return $item;
}

sub report_results {
    my $args    = shift;
    my $results = $args->{results};

    # Do some prep so the table makes sense.
    my $header = 'Spread';

    # What's our widest element?
    my $width_item  = 0;
    my $width_count = length $header;
    foreach my $item ( keys %{$results} ) {
        if ( length $item > $width_item ) { $width_item = length $item; }
        if ( length $results->{$item}->{count} > $width_count ) {
            $width_count = length $results->{$item}->{count};
        }
    }

    # Output strings for header and row.
    #<<< perltidy is not always my friend
    my $output_header = '%*s  %*s= % .3f  %s';
    my $output_row    = '%*s= %*d  %+.3f  %s';
    #>>>

    # header
    say sprintf "\n$output_header",
      $width_item, q{}, $width_count, $header, $spread, q{};

    # rows
    foreach my $item ( sort keys %{$results} ) {
        my $count = $results->{$item}->{count};

        # How close are we to 100% perfect?
        my $rate = $count / $option{sets} - 1;

        # Add a tag if we're out of bounds
        my $bad = q{};    # Needs a default
        if ( abs $rate > $spread ) { $bad = ' <<<'; }

        # Output
        say sprintf $output_row,
          $width_item, $item, $width_count, $count, $rate, $bad;

    }
    return;
}
