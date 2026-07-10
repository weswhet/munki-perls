use 5.012;
use strict;
use warnings;

use Encode qw(encode);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use Test::More;
use lib 'conditions/lib';
use MunkiPerls::Facts qw(
    backtomymac_configured crashplan_username local_user_dirs mdm_managed_user
);
use MunkiPerls qw(foundation_array foundation_dictionary foundation_string);
use Foundation;

my $directory = tempdir(CLEANUP => 1);
is(crashplan_username("$directory/missing"), '', 'missing CrashPlan file returns empty string');

my $identity = "$directory/identity";
open(my $identity_fh, '>', $identity) or die $!;
binmode $identity_fh;
print {$identity_fh} "token=value\n";
print {$identity_fh} "username=" . encode('UTF-8', "J\x{00fc}rgen") . "  \r\n";
print {$identity_fh} "username=second\n";
close $identity_fh;
is(crashplan_username($identity), "J\x{00fc}rgen", 'first Unicode username is returned with trailing whitespace removed');

open($identity_fh, '>', $identity) or die $!;
print {$identity_fh} " username=indented\nusername=valid\n";
close $identity_fh;
is(crashplan_username($identity), 'valid', 'only a property beginning with username is accepted');

SKIP: {
    skip 'unreadable file behavior is not meaningful as root', 1 if $> == 0;
    chmod 0000, $identity;
    is(crashplan_username($identity), '', 'unreadable CrashPlan file returns empty string');
    chmod 0600, $identity;
}

ok(backtomymac_configured(
    version => '10.14.6',
    probe => sub { return (1, "<dictionary> {\n  key : value\n}\n") },
), 'Back to My Mac key present on Mojave');
ok(!backtomymac_configured(
    version => '10.14.6',
    probe => sub { return (1, "No : Setup:/Network/BackToMyMac\n") },
), 'missing Back to My Mac key is false');
ok(!backtomymac_configured(
    version => '10.14.6',
    probe => sub { return (1, "unexpected output\n") },
), 'malformed scutil output is false');
ok(!backtomymac_configured(
    version => '10.14.6',
    probe => sub { return (0, '') },
), 'failed scutil command is false');
my $called = 0;
ok(!backtomymac_configured(
    version => '10.15',
    probe => sub { $called++; return (1, '<dictionary> {') },
), 'Catalina and newer are unconditionally false');
is($called, 0, 'Catalina and newer do not invoke scutil');

my $users = "$directory/Users";
make_path("$users/alice", "$users/bob", "$users/Shared", "$users/admin", "$users/Deleted Users", "$users/.hidden");
is_deeply([local_user_dirs($users)], [qw(alice bob)], 'local user directories use native sorted directory traversal');

my $uuid = '12345678-1234-1234-1234-123456789ABC';
my $profile_root = foundation_array();
my $profile = foundation_dictionary();
$profile->setObject_forKey_(foundation_string($uuid), foundation_string('Managed User'));
$profile_root->addObject_($profile);
my $profile_data = NSPropertyListSerialization->dataWithPropertyList_format_options_error_(
    $profile_root, 100, 0, undef
);
my $profile_path = "$directory/profile.plist";
$profile_data->writeToFile_options_error_(foundation_string($profile_path), 1, undef);
open(my $profile_fh, '<', $profile_path) or die $!;
binmode $profile_fh;
local $/;
my $profile_bytes = <$profile_fh>;
close $profile_fh;

is(mdm_managed_user(
    profile_output => $profile_bytes,
    directory_search => sub { return (1, "alice\tGeneratedUID = $uuid\n") },
), 'alice', 'managed UUID is resolved to a local username');
is(mdm_managed_user(
    profile_output => $profile_bytes,
    directory_search => sub { return (0, '') },
), $uuid, 'unresolved managed UUID is retained');
is(mdm_managed_user(profile_output => '<not plist>'), 'NONE', 'missing managed user returns NONE');

done_testing();
