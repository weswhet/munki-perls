#!/usr/bin/perl
use 5.012;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use MunkiPerls qw(fact_string run_condition);
use MunkiPerls::Facts qw(mdm_managed_user);
exit run_condition(\@ARGV, sub {
    return { mdm_managed_user => fact_string(mdm_managed_user()) };
});
