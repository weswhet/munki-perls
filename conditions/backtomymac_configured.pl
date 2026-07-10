#!/usr/bin/perl
use 5.012;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use MunkiPerls qw(fact_bool run_condition);
use MunkiPerls::Facts qw(backtomymac_configured);
exit run_condition(\@ARGV, sub {
    return {
        backtomymac_configured => fact_bool(backtomymac_configured())
    };
});
