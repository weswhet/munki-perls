use 5.012;
use strict;
use warnings;

use File::Find;
use Test::More;
use lib 'conditions/lib';
use MunkiPerls::Facts ();

is_deeply(
    [sort @MunkiPerls::Facts::EXPORT_OK],
    [qw(command_status console_user_facts)],
    'shared facts module exports only multi-fact helpers'
);

my @files;
find(
    sub {
        push @files, $File::Find::name
            if -f $_ && /\.(?:pl|pm)\z/;
    },
    'conditions', 'tools'
);

my %approved = map { $_ => 1 } qw(
    /usr/bin/csrutil
    /usr/bin/dscl
    /usr/bin/fdesetup
    /usr/bin/pkgbuild
    /usr/sbin/ioreg
    /usr/sbin/scutil
    /usr/sbin/spctl
    /usr/sbin/sysctl
    /usr/sbin/system_profiler
);

for my $file (sort @files) {
    open(my $fh, '<', $file) or die $!;
    local $/;
    my $source = <$fh>;
    close $fh;

    unlike($source, qr{/(?:usr/)?(?:bin|sbin)/(?:plutil|defaults|osascript)\b}, "$file has no forbidden plist executable");
    unlike($source, qr{PlistBuddy|JSON}, "$file has no forbidden plist helper or conversion");
    unlike($source, qr/`|\bqx\s*[\x2f({]/, "$file has no shell command interpolation");
    unlike($source, qr{\|\s*(?:awk|cut|grep|head|sed)\b}, "$file has no shell pipeline");

    while ($source =~ m{['"](/usr/(?:bin|sbin)/[A-Za-z0-9_.-]+)['"]}g) {
        ok($approved{$1}, "$file subprocess path $1 is allowlisted");
    }
    if ($file ne 'tools/build-pkg.pl'
            && $file ne 'conditions/lib/MunkiPerls.pm') {
        unlike($source, qr{\bsystem\s*(?:\{|\()|\bexec\s*(?:\{|\()}, "$file does not invoke subprocesses outside the shared direct runner");
    }
}

done_testing();
