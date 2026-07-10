#!/usr/bin/perl
use 5.012;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use MunkiPerls qw(fact_string run_condition);
use MunkiPerls::Facts qw(crashplan_username);
exit run_condition(\@ARGV, sub {
    return { crashplan_username => fact_string(crashplan_username()) };
});
