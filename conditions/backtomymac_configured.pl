#!/usr/bin/perl
use 5.008008;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
package MunkiPerls::Condition::BackToMyMacConfigured;
use MunkiPerls qw(fact_bool run_command run_condition system_version);
use MunkiPerls::Upgrade qw(is_version_at_least);

sub backtomymac_configured {
    my (%options) = @_;
    my $version = defined($options{version})
        ? $options{version}
        : system_version($options{system_version_path});
    # Catalina settled this question for us.
    return 0 if is_version_at_least($version, '10.15');

    my ($ok, $output);
    if ($options{probe}) {
        ($ok, $output) = $options{probe}->();
    } else {
        ($ok, $output) = run_command(
            { stdin => "show Setup:/Network/BackToMyMac\n" },
            '/usr/sbin/scutil'
        );
    }
    return 0 unless $ok;
    return $output =~ /\A\s*<dictionary>\s*\{/ ? 1 : 0;
}

unless (caller) {
    exit run_condition(\@ARGV, sub {
        return {
            backtomymac_configured => fact_bool(backtomymac_configured())
        };
    });
}
1;
