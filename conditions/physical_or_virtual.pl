#!/usr/bin/perl
use 5.012;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use MunkiPerls qw(fact_string run_condition);
use MunkiPerls::Facts qw(physical_or_virtual);
exit run_condition(\@ARGV, sub {
    return {
        physical_or_virtual => fact_string(physical_or_virtual())
    };
});
