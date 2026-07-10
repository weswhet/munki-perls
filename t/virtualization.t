use 5.012;
use strict;
use warnings;

use Test::More;
use lib 'conditions/lib';
use Foundation;
use MunkiPerls qw(
    foundation_array foundation_dictionary foundation_string objc_string
);
use MunkiPerls::Facts qw(physical_or_virtual virtualization_facts);

sub profiler_fixture {
    my (%values) = @_;
    my $root = foundation_array();

    my $ethernet_group = foundation_dictionary();
    my $ethernet_items = foundation_array();
    my $ethernet = foundation_dictionary();
    $ethernet->setObject_forKey_(
        foundation_string($values{ethernet_vendor}),
        foundation_string('spethernet_vendor-id')
    ) if defined $values{ethernet_vendor};
    $ethernet_items->addObject_($ethernet);
    $ethernet_group->setObject_forKey_(
        $ethernet_items, foundation_string('_items')
    );
    $root->addObject_($ethernet_group);

    my $hardware_group = foundation_dictionary();
    my $hardware_items = foundation_array();
    my $hardware = foundation_dictionary();
    $hardware->setObject_forKey_(
        foundation_string($values{boot_rom}),
        foundation_string('boot_rom_version')
    ) if defined $values{boot_rom};
    $hardware_items->addObject_($hardware);
    $hardware_group->setObject_forKey_(
        $hardware_items, foundation_string('_items')
    );
    $root->addObject_($hardware_group);

    my $data = NSPropertyListSerialization->dataWithPropertyList_format_options_error_(
        $root, 100, 0, undef
    );
    my $string = NSString->alloc()->initWithData_encoding_($data, 4);
    return objc_string($string);
}

my $physical_probe_count = 0;
my $physical = virtualization_facts(
    hardware_snapshot => { is_virtual => 0 },
    profiler_probe => sub {
        $physical_probe_count++;
        return (1, profiler_fixture(boot_rom => 'VMW'));
    },
);
is_deeply($physical, {
    machine_type => 'physical',
    physical_or_virtual => 'physical',
}, 'physical systems return both physical values');
is($physical_probe_count, 0, 'physical systems do not invoke system_profiler');

my @classifications = (
    ['vmware', profiler_fixture(boot_rom => 'VMW71.00V.21100432.B64.2201181744')],
    ['virtualbox', profiler_fixture(boot_rom => 'VirtualBox')],
    ['parallels', profiler_fixture(ethernet_vendor => 'vendor-id: 0x1ab8')],
    ['parallels', profiler_fixture(ethernet_vendor => '0X1AF4')],
    ['unknown_virtual', profiler_fixture(boot_rom => 'Other', ethernet_vendor => '0x1234')],
    ['unknown_virtual', 'not a property list'],
);

for my $case (@classifications) {
    my ($expected, $fixture) = @{$case};
    my $probe_count = 0;
    my $facts = virtualization_facts(
        hardware_snapshot => { is_virtual => 1 },
        profiler_probe => sub {
            $probe_count++;
            return (1, $fixture);
        },
    );
    is($facts->{machine_type}, $expected, "$expected virtual machine is classified");
    is($facts->{physical_or_virtual}, 'virtual', "$expected remains virtual in physical_or_virtual");
    is($probe_count, 1, "$expected classification uses one profiler probe");
    is_deeply(
        [sort keys %{$facts}],
        [qw(machine_type physical_or_virtual)],
        "$expected classification returns both facts together"
    );
}

my $failed = virtualization_facts(
    hardware_snapshot => { is_virtual => 1 },
    profiler_probe => sub { return (0, '') },
);
is($failed->{machine_type}, 'unknown_virtual', 'failed profiler output is unknown virtual');
is($failed->{physical_or_virtual}, 'virtual', 'failed profiler output remains virtual');

is(
    physical_or_virtual(hardware_snapshot => { is_virtual => 1 }),
    'virtual',
    'physical_or_virtual compatibility wrapper retains its two-value contract'
);

done_testing();
