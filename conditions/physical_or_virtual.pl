#!/usr/bin/perl
use 5.012;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use MunkiPerls qw(fact_string run_condition);
use MunkiPerls::Facts qw(virtualization_facts);
exit run_condition(\@ARGV, sub {
    my $values = virtualization_facts();
    return {
        machine_type => fact_string($values->{machine_type}),
        physical_or_virtual => fact_string($values->{physical_or_virtual}),
    };
});
