use 5.012;
use strict;
use warnings;

use File::Temp qw(tempdir);
use Test::More;
use lib 'conditions/lib';
use Foundation;
use MunkiPerls qw(
    foundation_array foundation_dictionary foundation_string
);

my $directory = tempdir(CLEANUP => 1);
my $input = "$directory/assets.plist";
my $root = foundation_dictionary();
my $assets = foundation_array();
for my $models (
    ['Mac15,3', 'Mac14,2'],
    ['Mac14,2', 'Mac16,1'],
) {
    my $asset = foundation_dictionary();
    my $supported = foundation_array();
    $supported->addObject_(foundation_string($_)) for @{$models};
    $asset->setObject_forKey_(
        $supported, foundation_string('SupportedDeviceModels')
    );
    $assets->addObject_($asset);
}
$root->setObject_forKey_($assets, foundation_string('Assets'));
my $data = NSPropertyListSerialization->dataWithPropertyList_format_options_error_(
    $root, 100, 0, undef
);
ok($data->writeToFile_options_error_(foundation_string($input), 1, undef), 'writes installer fixture with Foundation');

my $tool = 'tools/extract_supported_devices.pl';
open(my $child, '-|', $tool, '--input', $input) or die $!;
local $/;
my $output = <$child>;
close $child;
is($?, 0, 'extractor succeeds');
is($output, "qw(\n    Mac14,2\n    Mac15,3\n    Mac16,1\n)\n", 'models are validated, deduplicated, and sorted');

my $bad_input = "$directory/bad.plist";
my $bad_root = foundation_array();
$data = NSPropertyListSerialization->dataWithPropertyList_format_options_error_(
    $bad_root, 100, 0, undef
);
$data->writeToFile_options_error_(foundation_string($bad_input), 1, undef);
open($child, '-|', $tool, '--input', $bad_input) or die $!;
while (<$child>) { }
close $child;
isnt($?, 0, 'extractor rejects a non-dictionary root');

done_testing();
