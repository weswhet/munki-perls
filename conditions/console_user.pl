#!/usr/bin/perl
use 5.008008;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use MunkiPerls qw(perl_string run_condition);
use MunkiPerls::Perls qw(console_user_perls);
exit run_condition(\@ARGV, sub {
    my ($username) = console_user_perls();
    return { console_user => perl_string($username) };
});
