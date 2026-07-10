#!/usr/bin/perl
use 5.012;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use MunkiPerls qw(fact_bool run_condition);
use MunkiPerls::Upgrade qw(
    collect_hardware_snapshot evaluate_upgrade_facts
);
exit run_condition(\@ARGV, sub {
    my $values = evaluate_upgrade_facts(collect_hardware_snapshot());
    my %facts = map { $_ => fact_bool($values->{$_}) } keys %{$values};
    return \%facts;
});
