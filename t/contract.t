use 5.012;
use strict;
use warnings;

use File::Temp qw(tempdir);
use Scalar::Util qw(blessed);
use Test::More;
use lib 'conditions/lib';
use Foundation;
use MunkiPerls qw(foundation_string load_plist_file objc_string);

my $directory = tempdir(CLEANUP => 1);
my $output = "$directory/ConditionalItems.plist";
my @scripts = sort glob('conditions/*.pl');
is(scalar @scripts, 11, 'eleven condition executables are installed');

for my $script (@scripts) {
    ok(-x $script, "$script is executable");
    my $status = system { $script } $script, '--output', $output;
    is($status, 0, "$script runs successfully");
}

my $plist = load_plist_file($output, dictionary => 1);
ok(blessed($plist) && $$plist, 'combined output is a dictionary plist');

my @expected = sort qw(
    admin_users
    backtomymac_configured
    bigsur_upgrade_supported
    catalina_upgrade_supported
    console_user
    console_user_logged_in
    crashplan_username
    filevault_status
    gatekeeper_status
    goldengate_upgrade_supported
    local_user_dirs
    machine_type
    mdm_managed_user
    mojave_upgrade_supported
    monterey_upgrade_supported
    physical_or_virtual
    sequoia_upgrade_supported
    sierra_upgrade_supported
    sip_status
    sonoma_upgrade_supported
    tahoe_upgrade_supported
    ventura_upgrade_supported
);

my @actual;
my $keys = $plist->keyEnumerator();
while (my $key = $keys->nextObject()) {
    last unless blessed($key) && $$key;
    push @actual, objc_string($key);
}
is_deeply([sort @actual], \@expected, 'complete exact 22-key contract');

my %arrays = map { $_ => 1 } qw(admin_users local_user_dirs);
my %strings = map { $_ => 1 } qw(
    console_user crashplan_username filevault_status gatekeeper_status
    machine_type mdm_managed_user physical_or_virtual sip_status
);
for my $key (@expected) {
    my $value = $plist->objectForKey_(foundation_string($key));
    ok(blessed($value) && $$value, "$key has a native value");
    if ($arrays{$key}) {
        ok($value->isKindOfClass_(NSArray->class()), "$key is an array");
        my $items = $value->objectEnumerator();
        while (my $item = $items->nextObject()) {
            last unless blessed($item) && $$item;
            ok($item->isKindOfClass_(NSString->class()), "$key item is a string");
        }
    } elsif ($strings{$key}) {
        ok($value->isKindOfClass_(NSString->class()), "$key is a string");
    } else {
        ok($value->isKindOfClass_(NSNumber->class()), "$key is a number");
        is($value->objCType(), 'c', "$key is specifically a plist boolean");
    }
}

done_testing();
