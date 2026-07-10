use 5.008008;
use strict;
use warnings;

use File::Path qw(mkpath);
use File::Temp qw(tempdir);
use Test::More;

if (!-x '/usr/bin/pkgbuild') {
    plan skip_all => '/usr/bin/pkgbuild is required to build packages';
}
plan 'no_plan';

my $directory = tempdir(CLEANUP => 1);
my $package = "$directory/munki-perls-0.1.42.pkg";
my $status = system {
    $^X
} $^X, 'tools/build-pkg.pl', '--version', '0.1.42', '--output', $package;
is($status, 0, 'package builds');
ok(-f $package, 'unsigned package file exists');

my $expanded = "$directory/expanded";
$status = system {
    '/usr/sbin/pkgutil'
} '/usr/sbin/pkgutil', '--expand', $package, $expanded;
is($status, 0, 'pkgutil expands package');

open(my $info, '<', "$expanded/PackageInfo") or die $!;
local $/;
my $package_info = <$info>;
close $info;
like($package_info, qr{identifier="com\.github\.weswhet\.munki-perls"}, 'package identifier is correct');
like($package_info, qr{version="0\.1\.42"}, 'configured package version is correct');
like($package_info, qr{install-location="/usr/local/munki/conditions"}, 'install location is correct');

open(my $bom, '-|', '/usr/bin/lsbom', "$expanded/Bom") or die $!;
my $listing = <$bom>;
close $bom;
is($?, 0, 'lsbom inspects package');
my @executables = $listing =~ /^\.\/([^\.][^\/]*\.pl)\s+100755\b/gm;
is_deeply(
    \@executables,
    ['munki_perls.pl'],
    'package contains one top-level discovery runner'
);
like(
    $listing,
    qr{\./perls/system_extensions\.pl\s+100644\b},
    'package contains non-executable system-extension inventory plugin'
);
like(
    $listing,
    qr{\./perls/sierra_upgrade_supported\.pl\s+100644\b},
    'package contains non-executable split upgrade plugins'
);
unlike($listing, qr{\./system_extensions\.pl}, 'legacy top-level plugins are absent');
unlike($listing, qr{\./macos_upgrade_supported\.pl}, 'package excludes removed aggregate upgrade condition');
like($listing, qr{\./lib/MunkiPerls\.pm}, 'package contains shared Foundation runtime');
like(
    $listing,
    qr{\./lib/MunkiPerls/Plugins\.pm\s+100644\b},
    'package contains the plugin runtime'
);

ok(-x "$expanded/Scripts/postinstall", 'package contains executable postinstall cleanup');

my $legacy_install = "$directory/legacy-install";
mkpath("$legacy_install/perls", 0, 0755);
for my $path (
    "$legacy_install/admin_users.pl",
    "$legacy_install/site_custom.pl",
    "$legacy_install/perls/site_custom.pl",
) {
    open(my $file, '>', $path) or die $!;
    print {$file} "test\n";
    close $file or die $!;
}
{
    local $ENV{MUNKI_PERLS_CONDITIONS_DIR} = $legacy_install;
    $status = system {
        $^X
    } $^X, 'tools/pkg-scripts/postinstall';
}
is($status, 0, 'legacy cleanup runs against an injected installation');
ok(!-e "$legacy_install/admin_users.pl", 'known legacy executable is removed');
ok(-e "$legacy_install/site_custom.pl", 'unrelated top-level condition is preserved');
ok(-e "$legacy_install/perls/site_custom.pl", 'custom plugin is preserved');
