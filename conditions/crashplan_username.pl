#!/usr/bin/perl
use 5.012;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
package MunkiPerls::Condition::CrashPlanUsername;
use Encode qw(decode FB_DEFAULT);
use MunkiPerls qw(fact_string run_condition);

sub crashplan_username {
    my ($path) = @_;
    $path ||= '/Library/Application Support/CrashPlan/.identity';
    open(my $identity, '<', $path) or return '';
    binmode $identity;
    while (my $line = <$identity>) {
        next unless $line =~ /\Ausername=(.*)\z/s;
        my $username = $1;
        $username =~ s/\s+\z//;
        close $identity;
        return decode('UTF-8', $username, FB_DEFAULT);
    }
    close $identity;
    return '';
}

unless (caller) {
    exit run_condition(\@ARGV, sub {
        return { crashplan_username => fact_string(crashplan_username()) };
    });
}
1;
