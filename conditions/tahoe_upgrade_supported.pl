#!/usr/bin/perl
use 5.008008;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use MunkiPerls qw(perl_bool run_condition);
use MunkiPerls::Upgrade qw(cached_hardware_snapshot evaluate_upgrade_perl);
my $key = 'tahoe_upgrade_supported';
exit run_condition(\@ARGV, sub {
    my ($context) = @_;
    my $snapshot = cached_hardware_snapshot($context->{output_path});
    return { $key => perl_bool(evaluate_upgrade_perl($key, $snapshot)) };
});
