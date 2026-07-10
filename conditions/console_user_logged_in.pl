#!/usr/bin/perl
use 5.008008;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use MunkiPerls qw(perl_bool run_condition);
use MunkiPerls::Perls qw(console_user_perls);
exit run_condition(\@ARGV, sub {
    my (undef, $logged_in) = console_user_perls();
    return { console_user_logged_in => perl_bool($logged_in) };
});
