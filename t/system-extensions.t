use 5.008008;
use strict;
use warnings;

use File::Temp qw(tempdir);
use Test::More 'no_plan';
use lib 'conditions/lib';
use Foundation;
use MunkiPerls qw(
    foundation_array foundation_dictionary foundation_string write_plist_file
);

require './conditions/system_extensions.pl';

sub extension_row {
    my ($state, $identifier) = @_;
    my $row = foundation_dictionary();
    $row->setObject_forKey_(
        foundation_string($state), foundation_string('state')
    ) if defined $state;
    $row->setObject_forKey_(
        foundation_string($identifier), foundation_string('identifier')
    ) if defined $identifier;
    return $row;
}

my $directory = tempdir(CLEANUP => 1);
my $database_path = "$directory/db.plist";
my $database = foundation_dictionary();
my $extensions = foundation_array();

for my $row (
    extension_row('activated_enabled', 'com.example.zulu'),
    extension_row('activated_enabled', 'com.example.alpha'),
    extension_row('activated_enabled', 'com.example.alpha'),
    extension_row('activated_disabled', 'com.example.disabled'),
    extension_row('activated_waiting_for_user', 'com.example.waiting'),
    extension_row('activated_waiting_for_upgrade', 'com.example.upgrade'),
    extension_row(
        'terminated_waiting_to_uninstall_on_reboot',
        'com.example.uninstalling'
    ),
    extension_row('activated_enabled', ''),
    extension_row('activated_enabled', undef),
    extension_row(undef, 'com.example.missing-state'),
) {
    $extensions->addObject_($row);
}
$extensions->addObject_(foundation_string('malformed row'));
$database->setObject_forKey_($extensions, foundation_string('extensions'));
ok(write_plist_file($database_path, $database), 'writes system-extension fixture');

is_deeply(
    [MunkiPerls::Condition::SystemExtensions::system_extensions($database_path)],
    [qw(com.example.alpha com.example.zulu)],
    'returns only sorted, deduplicated, activated and enabled bundle IDs'
);

my $missing_path = "$directory/pre-catalina.plist";
is_deeply(
    [MunkiPerls::Condition::SystemExtensions::system_extensions($missing_path)],
    [],
    'a pre-Catalina system without the database returns an empty array'
);

my $malformed_path = "$directory/malformed.plist";
open(my $malformed, '>', $malformed_path) or die $!;
print {$malformed} 'not a property list';
close $malformed;
is_deeply(
    [MunkiPerls::Condition::SystemExtensions::system_extensions($malformed_path)],
    [],
    'a malformed database returns an empty array'
);

my $wrong_shape_path = "$directory/wrong-shape.plist";
my $wrong_shape = foundation_dictionary();
$wrong_shape->setObject_forKey_(
    foundation_string('not an array'), foundation_string('extensions')
);
ok(write_plist_file($wrong_shape_path, $wrong_shape), 'writes wrong-shape fixture');
is_deeply(
    [MunkiPerls::Condition::SystemExtensions::system_extensions($wrong_shape_path)],
    [],
    'a database without an extensions array returns an empty array'
);
