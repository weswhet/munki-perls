#!/usr/bin/perl
use 5.012;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use MunkiPerls qw(fact_array run_condition);
use MunkiPerls::Facts qw(admin_users);
exit run_condition(\@ARGV, sub {
    return { admin_users => fact_array(admin_users()) };
});
