#!/usr/bin/perl
use 5.008008;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use MunkiPerls qw(fact_bool run_condition);
use MunkiPerls::Facts qw(console_user_facts);
exit run_condition(\@ARGV, sub {
    my (undef, $logged_in) = console_user_facts();
    return { console_user_logged_in => fact_bool($logged_in) };
});
