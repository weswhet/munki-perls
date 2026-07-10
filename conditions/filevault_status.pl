#!/usr/bin/perl
use 5.012;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use MunkiPerls qw(fact_string run_condition);
use MunkiPerls::Facts qw(command_status);
exit run_condition(\@ARGV, sub {
    return {
        filevault_status => fact_string(
            command_status('/usr/bin/fdesetup', 'status')
        )
    };
});
