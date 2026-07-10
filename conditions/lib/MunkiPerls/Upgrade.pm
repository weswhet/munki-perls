package MunkiPerls::Upgrade;

use 5.012;
use strict;
use warnings;
no warnings 'qw';

use Exporter qw(import);
use Scalar::Util qw(blessed);

use MunkiPerls qw(
    foundation_string objc_string parse_plist_output run_command system_version
);

our @EXPORT_OK = qw(
    collect_hardware_snapshot evaluate_upgrade_facts
    is_version_at_least version_compare
);

my %MOJAVE_BLOCKED_MODEL = map { $_ => 1 } qw(
        MacBookPro4,1
        MacPro2,1
        Macmini5,2
        Macmini5,1
        MacBookPro5,1
        MacBookPro1,1
        MacBookPro5,3
        MacBookPro5,2
        iMac8,1
        MacBookPro5,4
        MacBookAir4,2
        Macmini2,1
        iMac5,2
        iMac11,3
        MacBookPro8,2
        MacBookPro3,1
        Macmini5,3
        MacBookPro1,2
        Macmini4,1
        iMac9,1
        iMac6,1
        Macmini3,1
        Macmini1,1
        MacBookPro6,1
        MacBookPro2,2
        MacBookPro2,1
        iMac12,2
        MacBook3,1
        MacPro3,1
        MacBook5,1
        MacBook5,2
        iMac11,1
        iMac10,1
        MacBookPro7,1
        MacBook2,1
        MacBookAir4,1
        MacPro4,1
        MacBookPro6,2
        iMac12,1
        MacBook1,1
        MacBookPro5,5
        iMac11,2
        iMac4,2
        Xserve2,1
        MacBookAir3,1
        MacBookAir3,2
        MacBookAir1,1
        Xserve3,1
        iMac4,1
        MacBookAir2,1
        Xserve1,1
        iMac5,1
        MacBookPro8,1
        MacBook7,1
        MacBookPro8,3
        iMac7,1
        MacBook6,1
        MacBook4,1
        MacPro1,1
    );
my %MOJAVE_BOARD = map { $_ => 1 } qw(
        Mac-06F11F11946D27C5
        Mac-031B6874CF7F642A
        Mac-CAD6701F7CEA0921
        Mac-50619A408DB004DA
        Mac-7BA5B2D9E42DDD94
        Mac-473D31EABEB93F9B
        Mac-AFD8A9D944EA4843
        Mac-B809C3757DA9BB8D
        Mac-7DF2A3B5E5D671ED
        Mac-35C1E88140C3E6CF
        Mac-77EB7D7DAF985301
        Mac-2E6FAB96566FE58C
        Mac-827FB448E656EC26
        Mac-BE0E8AC46FE800CC
        Mac-00BE6ED71E35EB86
        Mac-4B7AC7E43945597E
        Mac-5A49A77366F81C72
        Mac-35C5E08120C7EEAF
        Mac-FFE5EF870D7BA81A
        Mac-C6F71043CEAA02A6
        Mac-4B682C642B45593E
        Mac-90BE64C3CB5A9AEB
        Mac-66F35F19FE2A0D05
        Mac-189A3D4F975D5FFC
        Mac-B4831CEBD52A0C4C
        Mac-FA842E06C61E91C5
        Mac-FC02E91DDD3FA6A4
        Mac-06F11FD93F0323C5
        Mac-9AE82516C7C6B903
        Mac-27ADBB7B4CEE8E61
        Mac-6F01561E16C75D06
        Mac-F60DEB81FF30ACF6
        Mac-81E3E92DD6088272
        Mac-7DF21CB3ED6977E5
        Mac-937CB26E2E02BB01
        Mac-3CBD00234E554E41
        Mac-F221BEC8
        Mac-9F18E312C5C2BF0B
        Mac-65CE76090165799A
        Mac-CF21D135A7D34AA6
        Mac-F65AE981FFA204ED
        Mac-112B0A653D3AAB9C
        Mac-DB15BD556843C820
        Mac-937A206F2EE63C01
        Mac-77F17D7DA9285301
        Mac-C3EC7CD22292981F
        Mac-BE088AF8C5EB4FA2
        Mac-551B86E5744E2388
        Mac-A5C67F76ED83108C
        Mac-031AEE4D24BFF0B1
        Mac-EE2EBD4B90B839A8
        Mac-42FD25EABCABB274
        Mac-F305150B0C7DEEEF
        Mac-2BD1B31983FE1663
        Mac-66E35819EE2D0D05
        Mac-A369DDC4E67F1C45
        Mac-E43C1C25D4880AD6
    );
my %CATALINA_BLOCKED_MODEL = map { $_ => 1 } qw(
        iMac4,1
        iMac4,2
        iMac5,1
        iMac5,2
        iMac6,1
        iMac7,1
        iMac8,1
        iMac9,1
        iMac10,1
        iMac11,1
        iMac11,2
        iMac11,3
        iMac12,1
        iMac12,2
        MacBook1,1
        MacBook2,1
        MacBook3,1
        MacBook4,1
        MacBook5,1
        MacBook5,2
        MacBook6,1
        MacBook7,1
        MacBookAir1,1
        MacBookAir2,1
        MacBookAir3,1
        MacBookAir3,2
        MacBookAir4,1
        MacBookAir4,2
        MacBookPro1,1
        MacBookPro1,2
        MacBookPro2,1
        MacBookPro2,2
        MacBookPro3,1
        MacBookPro4,1
        MacBookPro5,1
        MacBookPro5,2
        MacBookPro5,3
        MacBookPro5,4
        MacBookPro5,5
        MacBookPro6,1
        MacBookPro6,2
        MacBookPro7,1
        MacBookPro8,1
        MacBookPro8,2
        MacBookPro8,3
        Macmini1,1
        Macmini2,1
        Macmini3,1
        Macmini4,1
        Macmini5,1
        Macmini5,2
        Macmini5,3
        MacPro1,1
        MacPro2,1
        MacPro3,1
        MacPro4,1
        MacPro5,1
        Xserve1,1
        Xserve2,1
        Xserve3,1
    );
my %CATALINA_BOARD = map { $_ => 1 } qw(
        Mac-00BE6ED71E35EB86
        Mac-1E7E29AD0135F9BC
        Mac-2BD1B31983FE1663
        Mac-2E6FAB96566FE58C
        Mac-3CBD00234E554E41
        Mac-4B7AC7E43945597E
        Mac-4B682C642B45593E
        Mac-5A49A77366F81C72
        Mac-06F11F11946D27C5
        Mac-06F11FD93F0323C5
        Mac-6F01561E16C75D06
        Mac-7BA5B2D9E42DDD94
        Mac-7BA5B2DFE22DDD8C
        Mac-7DF2A3B5E5D671ED
        Mac-7DF21CB3ED6977E5
        Mac-9AE82516C7C6B903
        Mac-9F18E312C5C2BF0B
        Mac-27AD2F918AE68F61
        Mac-27ADBB7B4CEE8E61
        Mac-031AEE4D24BFF0B1
        Mac-031B6874CF7F642A
        Mac-35C1E88140C3E6CF
        Mac-35C5E08120C7EEAF
        Mac-42FD25EABCABB274
        Mac-53FDB3D8DB8CA971
        Mac-65CE76090165799A
        Mac-66E35819EE2D0D05
        Mac-66F35F19FE2A0D05
        Mac-77EB7D7DAF985301
        Mac-77F17D7DA9285301
        Mac-81E3E92DD6088272
        Mac-90BE64C3CB5A9AEB
        Mac-112B0A653D3AAB9C
        Mac-189A3D4F975D5FFC
        Mac-226CB3C6A851A671
        Mac-473D31EABEB93F9B
        Mac-551B86E5744E2388
        Mac-747B1AEFF11738BE
        Mac-827FAC58A8FDFA22
        Mac-827FB448E656EC26
        Mac-937A206F2EE63C01
        Mac-937CB26E2E02BB01
        Mac-9394BDF4BF862EE7
        Mac-50619A408DB004DA
        Mac-63001698E7A34814
        Mac-112818653D3AABFC
        Mac-A5C67F76ED83108C
        Mac-A369DDC4E67F1C45
        Mac-AA95B1DDAB278B95
        Mac-AFD8A9D944EA4843
        Mac-B809C3757DA9BB8D
        Mac-B4831CEBD52A0C4C
        Mac-BE0E8AC46FE800CC
        Mac-BE088AF8C5EB4FA2
        Mac-C3EC7CD22292981F
        Mac-C6F71043CEAA02A6
        Mac-CAD6701F7CEA0921
        Mac-CF21D135A7D34AA6
        Mac-DB15BD556843C820
        Mac-E43C1C25D4880AD6
        Mac-EE2EBD4B90B839A8
        Mac-F60DEB81FF30ACF6
        Mac-F65AE981FFA204ED
        Mac-F305150B0C7DEEEF
        Mac-FA842E06C61E91C5
        Mac-FC02E91DDD3FA6A4
        Mac-FFE5EF870D7BA81A
    );

my @RELEASES = (
    {
        name => 'mojave',
        target => '10.14',
        minimum => '10.7',
        blocked_models => \%MOJAVE_BLOCKED_MODEL,
        boards => \%MOJAVE_BOARD,
        require_model_and_board => 1,
    },
    {
        name => 'catalina',
        target => '10.15',
        minimum => '10.9',
        blocked_models => \%CATALINA_BLOCKED_MODEL,
        boards => \%CATALINA_BOARD,
        require_model_and_board => 1,
    },
    {
        name => 'bigsur',
        target => '11',
        minimum => '10.7',
        models => { map { $_ => 1 } qw(
        MacBook10,1
        MacBook8,1
        MacBook9,1
        MacBookAir6,1
        MacBookAir6,2
        MacBookAir7,1
        MacBookAir7,2
        MacBookAir8,1
        MacBookAir8,2
        MacBookPro11,2
        MacBookPro11,3
        MacBookPro11,4
        MacBookPro11,5
        MacBookPro12,1
        MacBookPro13,1
        MacBookPro13,2
        MacBookPro13,3
        MacBookPro14,1
        MacBookPro14,2
        MacBookPro14,3
        MacBookPro15,1
        MacBookPro15,2
        MacBookPro15,3
        MacBookPro15,4
        MacPro6,1
        MacPro7,1
        Macmini7,1
        Macmini8,1
        iMac14,4
        iMac15,1
        iMac16,1
        iMac16,2
        iMac17,1
        iMac18,1
        iMac18,2
        iMac18,3
        iMac19,1
        iMac19,2
        iMacPro1,1
        VirtualMac2,1
    ) },
        boards => { map { $_ => 1 } qw(
        Mac-226CB3C6A851A671
        Mac-36B6B6DA9CFCD881
        Mac-112818653D3AABFC
        Mac-9394BDF4BF862EE7
        Mac-AA95B1DDAB278B95
        Mac-CAD6701F7CEA0921
        Mac-50619A408DB004DA
        Mac-7BA5B2D9E42DDD94
        Mac-CFF7D910A743CAAF
        Mac-B809C3757DA9BB8D
        Mac-F305150B0C7DEEEF
        Mac-35C1E88140C3E6CF
        Mac-827FAC58A8FDFA22
        Mac-6FEBD60817C77D8A
        Mac-7BA5B2DFE22DDD8C
        Mac-827FB448E656EC26
        Mac-66E35819EE2D0D05
        Mac-BE0E8AC46FE800CC
        Mac-5A49A77366F81C72
        Mac-63001698E7A34814
        Mac-937CB26E2E02BB01
        Mac-FFE5EF870D7BA81A
        Mac-87DCB00F4AD77EEA
        Mac-A61BADE1FDAD7B05
        Mac-C6F71043CEAA02A6
        Mac-4B682C642B45593E
        Mac-1E7E29AD0135F9BC
        Mac-90BE64C3CB5A9AEB
        Mac-3CBD00234E554E41
        Mac-B4831CEBD52A0C4C
        Mac-E1008331FDC96864
        Mac-FA842E06C61E91C5
        Mac-81E3E92DD6088272
        Mac-06F11FD93F0323C5
        Mac-06F11F11946D27C5
        Mac-F60DEB81FF30ACF6
        Mac-473D31EABEB93F9B
        Mac-0CFF9C7C2B63DF8D
        Mac-9F18E312C5C2BF0B
        Mac-E7203C0F68AA0004
        Mac-65CE76090165799A
        Mac-CF21D135A7D34AA6
        Mac-112B0A653D3AAB9C
        Mac-DB15BD556843C820
        Mac-27AD2F918AE68F61
        Mac-937A206F2EE63C01
        Mac-77F17D7DA9285301
        Mac-9AE82516C7C6B903
        Mac-BE088AF8C5EB4FA2
        Mac-551B86E5744E2388
        Mac-564FBA6031E5946A
        Mac-A5C67F76ED83108C
        Mac-5F9802EFE386AA28
        Mac-747B1AEFF11738BE
        Mac-AF89B6D9451A490B
        Mac-EE2EBD4B90B839A8
        Mac-42FD25EABCABB274
        Mac-2BD1B31983FE1663
        Mac-7DF21CB3ED6977E5
        Mac-A369DDC4E67F1C45
        Mac-35C5E08120C7EEAF
        Mac-E43C1C25D4880AD6
        Mac-53FDB3D8DB8CA971
        VMM-x86
    ) },
        hardware_targets => { map { $_ => 1 } () },
    },
    {
        name => 'monterey',
        target => '12',
        minimum => '10.7',
        models => { map { $_ => 1 } qw(
        MacBook10,1
        MacBook9,1
        MacBookAir7,1
        MacBookAir7,2
        MacBookAir8,1
        MacBookAir8,2
        MacBookAir9,1
        MacBookPro11,4
        MacBookPro11,5
        MacBookPro12,1
        MacBookPro13,1
        MacBookPro13,2
        MacBookPro13,3
        MacBookPro14,1
        MacBookPro14,2
        MacBookPro14,3
        MacBookPro15,1
        MacBookPro15,2
        MacBookPro15,3
        MacBookPro15,4
        MacBookPro16,1
        MacBookPro16,2
        MacBookPro16,3
        MacBookPro16,4
        MacPro6,1
        MacPro7,1
        Macmini7,1
        Macmini8,1
        iMac16,1
        iMac16,2
        iMac17,1
        iMac18,1
        iMac18,2
        iMac18,3
        iMac19,1
        iMac19,2
        iMac20,1
        iMac20,2
        iMacPro1,1
        VirtualMac2,1
    ) },
        boards => { map { $_ => 1 } qw(
        Mac-06F11F11946D27C5
        Mac-06F11FD93F0323C5
        Mac-0CFF9C7C2B63DF8D
        Mac-112818653D3AABFC
        Mac-1E7E29AD0135F9BC
        Mac-226CB3C6A851A671
        Mac-27AD2F918AE68F61
        Mac-35C5E08120C7EEAF
        Mac-473D31EABEB93F9B
        Mac-4B682C642B45593E
        Mac-53FDB3D8DB8CA971
        Mac-551B86E5744E2388
        Mac-5F9802EFE386AA28
        Mac-63001698E7A34814
        Mac-65CE76090165799A
        Mac-66E35819EE2D0D05
        Mac-77F17D7DA9285301
        Mac-7BA5B2D9E42DDD94
        Mac-7BA5B2DFE22DDD8C
        Mac-827FAC58A8FDFA22
        Mac-827FB448E656EC26
        Mac-937A206F2EE63C01
        Mac-937CB26E2E02BB01
        Mac-9AE82516C7C6B903
        Mac-9F18E312C5C2BF0B
        Mac-A369DDC4E67F1C45
        Mac-A5C67F76ED83108C
        Mac-A61BADE1FDAD7B05
        Mac-AA95B1DDAB278B95
        Mac-AF89B6D9451A490B
        Mac-B4831CEBD52A0C4C
        Mac-B809C3757DA9BB8D
        Mac-BE088AF8C5EB4FA2
        Mac-CAD6701F7CEA0921
        Mac-CFF7D910A743CAAF
        Mac-DB15BD556843C820
        Mac-E1008331FDC96864
        Mac-E43C1C25D4880AD6
        Mac-E7203C0F68AA0004
        Mac-EE2EBD4B90B839A8
        Mac-F60DEB81FF30ACF6
        Mac-FFE5EF870D7BA81A
        VMM-x86
    ) },
        hardware_targets => { map { $_ => 1 } qw(
        J132AP
        J137AP
        J140AAP
        J140KAP
        J152FAP
        J160AP
        J174AP
        J185AP
        J185FAP
        J213AP
        J214AP
        J214KAP
        J215AP
        J223AP
        J230AP
        J230KAP
        J274AP
        J293AP
        J313AP
        J314cAP
        J314sAP
        J316cAP
        J316sAP
        J456AP
        J457AP
        J680AP
        J780AP
        VMA2MACOSAP
        VMM-x86
        X589AMLUAP
        X86LEGACYAP
    ) },
    },
    {
        name => 'ventura',
        target => '13',
        minimum => '10.7',
        models => { map { $_ => 1 } qw(
        iMac18,1
        iMac18,2
        iMac18,3
        iMac19,1
        iMac19,2
        iMac20,1
        iMac20,2
        iMac21,1
        iMac21,2
        iMacPro1,1
        iSim1,1
        Mac13,1
        Mac13,2
        Mac14,2
        Mac14,7
        MacBook10,1
        MacBookAir10,1
        MacBookAir8,1
        MacBookAir8,2
        MacBookAir9,1
        MacBookPro14,1
        MacBookPro14,2
        MacBookPro14,3
        MacBookPro15,1
        MacBookPro15,2
        MacBookPro15,3
        MacBookPro15,4
        MacBookPro16,1
        MacBookPro16,2
        MacBookPro16,3
        MacBookPro16,4
        MacBookPro17,1
        MacBookPro18,1
        MacBookPro18,2
        MacBookPro18,3
        MacBookPro18,4
        Macmini8,1
        Macmini9,1
        MacPro7,1
        VirtualMac2,1
    ) },
        boards => { map { $_ => 1 } () },
        hardware_targets => { map { $_ => 1 } () },
    },
    {
        name => 'sonoma',
        target => '14',
        minimum => '10.7',
        models => { map { $_ => 1 } qw(
        iMac19,1
        iMac19,2
        iMac20,1
        iMac20,2
        iMac21,1
        iMac21,2
        iMacPro1,1
        iSim1,1
        Mac13,1
        Mac13,2
        Mac14,10
        Mac14,12
        Mac14,13
        Mac14,14
        Mac14,15
        Mac14,2
        Mac14,3
        Mac14,5
        Mac14,6
        Mac14,7
        Mac14,8
        Mac14,9
        Mac15,3
        Mac15,4
        Mac15,5
        Mac15,6
        Mac15,7
        Mac15,8
        Mac15,9
        MacBookAir10,1
        MacBookAir8,1
        MacBookAir8,2
        MacBookAir9,1
        MacBookPro15,1
        MacBookPro15,2
        MacBookPro15,3
        MacBookPro15,4
        MacBookPro16,1
        MacBookPro16,2
        MacBookPro16,3
        MacBookPro16,4
        MacBookPro17,1
        MacBookPro18,1
        MacBookPro18,2
        MacBookPro18,3
        MacBookPro18,4
        Macmini8,1
        Macmini9,1
        MacPro7,1
        VirtualMac2,1
    ) },
        boards => { map { $_ => 1 } () },
        hardware_targets => { map { $_ => 1 } () },
    },
    {
        name => 'sequoia',
        target => '15',
        minimum => '10.7',
        models => { map { $_ => 1 } qw(
        iMac19,1
        iMac19,2
        iMac20,1
        iMac20,2
        iMac21,1
        iMac21,2
        iMacPro1,1
        Mac13,1
        Mac13,2
        Mac14,2
        Mac14,3
        Mac14,5
        Mac14,6
        Mac14,7
        Mac14,8
        Mac14,9
        Mac14,10
        Mac14,12
        Mac14,13
        Mac14,14
        Mac14,15
        Mac15,3
        Mac15,4
        Mac15,5
        Mac15,6
        Mac15,7
        Mac15,8
        Mac15,9
        Mac15,10
        Mac15,11
        Mac15,12
        Mac15,13
        MacBookAir10,1
        MacBookAir9,1
        MacBookPro15,1
        MacBookPro15,2
        MacBookPro15,3
        MacBookPro15,4
        MacBookPro16,1
        MacBookPro16,2
        MacBookPro16,3
        MacBookPro16,4
        MacBookPro17,1
        MacBookPro18,1
        MacBookPro18,2
        MacBookPro18,3
        MacBookPro18,4
        Macmini8,1
        Macmini9,1
        MacPro7,1
        VirtualMac2,1
    ) },
        boards => { map { $_ => 1 } () },
        hardware_targets => { map { $_ => 1 } () },
    },
    {
        name => 'tahoe',
        target => '26',
        minimum => '10.7',
        models => { map { $_ => 1 } qw(
        iMac20,1
        iMac20,2
        iMac21,1
        iMac21,2
        Mac13,1
        Mac13,2
        Mac14,2
        Mac14,3
        Mac14,5
        Mac14,6
        Mac14,7
        Mac14,8
        Mac14,9
        Mac14,10
        Mac14,12
        Mac14,13
        Mac14,14
        Mac14,15
        Mac15,3
        Mac15,4
        Mac15,5
        Mac15,6
        Mac15,7
        Mac15,8
        Mac15,9
        Mac15,10
        Mac15,11
        Mac15,12
        Mac15,13
        Mac15,14
        Mac16,1
        Mac16,2
        Mac16,3
        Mac16,5
        Mac16,6
        Mac16,7
        Mac16,8
        Mac16,9
        Mac16,10
        Mac16,11
        Mac16,12
        Mac16,13
        Mac16,15
        MacBookAir10,1
        MacBookPro16,1
        MacBookPro16,2
        MacBookPro16,4
        MacBookPro17,1
        MacBookPro18,1
        MacBookPro18,2
        MacBookPro18,3
        MacBookPro18,4
        Macmini9,1
        MacPro7,1
        VirtualMac2,1
    ) },
        boards => { map { $_ => 1 } () },
        hardware_targets => { map { $_ => 1 } () },
    },
    {
        name => 'goldengate',
        target => '27',
        minimum => '10.7',
        models => { map { $_ => 1 } () },
        boards => { map { $_ => 1 } () },
        hardware_targets => { map { $_ => 1 } qw(
        J180dAP
        J274AP
        J293AP
        J313AP
        J314cAP
        J314sAP
        J316cAP
        J316sAP
        J375cAP
        J375dAP
        J413AP
        J414cAP
        J414sAP
        J415AP
        J416cAP
        J416sAP
        J433AP
        J434AP
        J456AP
        J457AP
        J473AP
        J474sAP
        J475cAP
        J475dAP
        J493AP
        J504AP
        J514cAP
        J514mAP
        J514sAP
        J516cAP
        J516mAP
        J516sAP
        J575cAP
        J575dAP
        J604AP
        J613AP
        J614cAP
        J614sAP
        J615AP
        J616cAP
        J616sAP
        J623AP
        J624AP
        J700AP
        J704AP
        J713AP
        J714cAP
        J714sAP
        J715AP
        J716cAP
        J716sAP
        J773gAP
        J773sAP
        J813AP
        J815AP
        VMA2MACOSAP
    ) },
    },
);

sub _version_parts {
    my ($version) = @_;
    return unless defined $version && $version =~ /\A(\d+)(?:\.(\d+))?(?:\.(\d+))?/;
    return ($1 + 0, defined($2) ? $2 + 0 : 0, defined($3) ? $3 + 0 : 0);
}

sub version_compare {
    my ($left, $right) = @_;
    my @left = _version_parts($left);
    my @right = _version_parts($right);
    return unless @left && @right;
    for my $index (0 .. 2) {
        return -1 if $left[$index] < $right[$index];
        return 1 if $left[$index] > $right[$index];
    }
    return 0;
}

sub is_version_at_least {
    my ($version, $minimum) = @_;
    my $comparison = version_compare($version, $minimum);
    return defined($comparison) && $comparison >= 0 ? 1 : 0;
}

sub _dictionary_value {
    my ($dictionary, $key) = @_;
    return '' unless blessed($dictionary) && $$dictionary;
    my $value = eval {
        $dictionary->objectForKey_(foundation_string($key));
    };
    return objc_string($value);
}

sub _ioreg_identity {
    my ($output) = @_;
    my $plist = parse_plist_output($output);
    return ('', '') unless blessed($plist) && $$plist;
    return ('', '') unless $plist->isKindOfClass_(NSArray->class());
    return ('', '') unless $plist->count();

    my $dictionary = $plist->objectAtIndex_(0);
    return ('', '') unless blessed($dictionary) && $$dictionary;
    return (
        _dictionary_value($dictionary, 'model'),
        _dictionary_value($dictionary, 'board-id')
    );
}

sub _sysctl {
    my ($name) = @_;
    my ($ok, $output) = run_command(
        {}, '/usr/sbin/sysctl', '-n', $name
    );
    return '' unless $ok;
    $output =~ s/[\r\n]+\z//;
    return $output;
}

sub collect_hardware_snapshot {
    my (%options) = @_;
    my $version = defined($options{version})
        ? $options{version}
        : system_version($options{system_version_path});

    my ($model, $board_id) = ('', '');
    if (defined $options{ioreg_output}) {
        ($model, $board_id) = _ioreg_identity($options{ioreg_output});
    } else {
        my ($ok, $output) = run_command(
            {}, '/usr/sbin/ioreg', '-a', '-rd1',
            '-c', 'IOPlatformExpertDevice'
        );
        ($model, $board_id) = _ioreg_identity($output) if $ok;
    }

    my $sysctl = sub {
        my ($name) = @_;
        if (ref($options{sysctl_values}) eq 'HASH'
                && exists $options{sysctl_values}{$name}) {
            return $options{sysctl_values}{$name};
        }
        return _sysctl($name);
    };

    my $hardware_target = defined($options{hardware_target})
        ? $options{hardware_target}
        : $sysctl->('hw.target');

    my $virtual;
    if (defined $options{is_virtual}) {
        $virtual = $options{is_virtual} ? 1 : 0;
    } elsif (is_version_at_least($version, '11')) {
        my $present = $sysctl->('kern.hv_vmm_present');
        $virtual = $present =~ /\A[1-9]\d*\z/ ? 1 : 0;
    } else {
        my $features = $sysctl->('machdep.cpu.features');
        $virtual = $features =~ /(?:\A|\s)VMM(?:\s|\z)/ ? 1 : 0;
    }

    return {
        version => $version,
        model => $model,
        board_id => $board_id,
        hardware_target => $hardware_target,
        is_virtual => $virtual,
    };
}

sub _physical_supported {
    my ($release, $snapshot) = @_;
    my $model = $snapshot->{model} || '';
    my $board = $snapshot->{board_id} || '';
    my $target = $snapshot->{hardware_target} || '';

    if ($release->{require_model_and_board}) {
        return 0 if !length($model) || $release->{blocked_models}{$model};
        return $release->{boards}{$board} ? 1 : 0;
    }
    return 1 if $release->{models}{$model};
    return 1 if $release->{boards}{$board};
    return 1 if $release->{hardware_targets}{$target};
    return 0;
}

sub evaluate_upgrade_facts {
    my ($snapshot) = @_;
    die "Hardware snapshot must be a hash reference\n"
        unless ref($snapshot) eq 'HASH';
    my %facts;
    for my $release (@RELEASES) {
        my $key = $release->{name} . '_upgrade_supported';
        my $supported = 0;
        my $at_target = version_compare(
            $snapshot->{version}, $release->{target}
        );
        my $at_minimum = version_compare(
            $snapshot->{version}, $release->{minimum}
        );

        # Being there already is not, strictly speaking, an upgrade path.
        if (!defined($at_target) || !defined($at_minimum)) {
            $supported = 0;
        } elsif ($at_target >= 0) {
            $supported = 0;
        } elsif ($at_minimum < 0) {
            $supported = 0;
        } elsif ($snapshot->{is_virtual}) {
            $supported = 1;
        } else {
            $supported = _physical_supported($release, $snapshot);
        }
        $facts{$key} = $supported;
    }
    return \%facts;
}

1;
