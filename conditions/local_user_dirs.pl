#!/usr/bin/perl
use 5.012;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use MunkiPerls qw(fact_array run_condition);
use MunkiPerls::Facts qw(local_user_dirs);
exit run_condition(\@ARGV, sub {
    return { local_user_dirs => fact_array(local_user_dirs()) };
});
