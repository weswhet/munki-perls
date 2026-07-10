#!/usr/bin/perl
use 5.012;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
package MunkiPerls::Condition::PhysicalOrVirtual;
use MunkiPerls qw(fact_string run_condition);
use MunkiPerls::Upgrade qw(cached_hardware_snapshot);

sub physical_or_virtual {
    my ($snapshot) = @_;
    return $snapshot->{is_virtual} ? 'virtual' : 'physical';
}

unless (caller) {
    exit run_condition(\@ARGV, sub {
        my ($context) = @_;
        my $snapshot = cached_hardware_snapshot($context->{output_path});
        return { physical_or_virtual => fact_string(
            physical_or_virtual($snapshot)
        ) };
    });
}
1;
