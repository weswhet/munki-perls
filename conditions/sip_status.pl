#!/usr/bin/perl
use 5.008008;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use MunkiPerls qw(perl_string run_condition);
use MunkiPerls::Perls qw(command_status);
exit run_condition(\@ARGV, sub {
    return {
        sip_status => perl_string(
            command_status('/usr/bin/csrutil', 'status')
        )
    };
});
