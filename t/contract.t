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
my @scripts = sort glob('conditions/*.pl');
is(scalar @scripts, 22, 'twenty-two condition executables are installed');

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

my %arrays = map { $_ => 1 } qw(admin_users local_user_dirs);
my %strings = map { $_ => 1 } qw(
    console_user crashplan_username filevault_status gatekeeper_status
    machine_type mdm_managed_user physical_or_virtual sip_status
);
my @actual;
for my $script (@scripts) {
    ok(-x $script, "$script is executable");
    (my $key = $script) =~ s{\Aconditions/|\.pl\z}{}g;
    my $output = "$directory/$key.plist";
    my $status = system { $script } $script, '--output', $output;
    is($status, 0, "$script runs successfully");

    my $plist = load_plist_file($output, dictionary => 1);
    ok(blessed($plist) && $$plist, "$script output is a dictionary plist");
    is($plist->count(), 1, "$script writes exactly one key");
    my $keys = $plist->keyEnumerator();
    my $only_key = $keys->nextObject();
    is(objc_string($only_key), $key, "$script key matches its basename");
    push @actual, $key;

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
is_deeply([sort @actual], \@expected, 'isolated outputs form the exact 22-key contract');

done_testing();
