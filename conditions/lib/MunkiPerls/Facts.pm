package MunkiPerls::Facts;

use 5.012;
use strict;
use warnings;

use Encode qw(decode FB_DEFAULT);
use Exporter qw(import);
use Scalar::Util qw(blessed);

use Foundation;
use MunkiPerls qw(
    foundation_string objc_string parse_plist_output run_command system_version
);
use MunkiPerls::Upgrade qw(
    collect_hardware_snapshot is_version_at_least
);

our @EXPORT_OK = qw(
    admin_users backtomymac_configured command_status console_user_facts
    crashplan_username local_user_dirs mdm_managed_user
    physical_or_virtual virtualization_facts
);

sub admin_users {
    my (undef, undef, undef, $members) = getgrnam('admin');
    return () unless defined $members && length $members;
    return sort grep { length $_ } split /\s+/, $members;
}

sub console_user_facts {
    my ($console_path) = @_;
    $console_path ||= '/dev/console';
    my @metadata = stat($console_path);
    my $username = '';
    if (@metadata) {
        my ($name) = getpwuid($metadata[4]);
        $username = $name if defined $name;
    }
    my $logged_in = $username !~ /\A(?:|root|loginwindow|_mbsetupuser)\z/;
    return ($username, $logged_in ? 1 : 0);
}

sub local_user_dirs {
    my ($users_path) = @_;
    $users_path ||= '/Users';
    opendir(my $directory, $users_path) or return ();
    my @entries = grep {
        $_ !~ /\A\./
            && $_ ne 'Deleted Users'
            && $_ ne 'Shared'
            && $_ ne 'admin'
    } readdir($directory);
    closedir $directory;
    return sort @entries;
}

sub command_status {
    my (@command) = @_;
    my ($ok, $output) = run_command({}, @command);
    return 'Unknown' unless $ok;
    $output =~ s/[\r\n]+\z//;
    return length($output) ? $output : 'Unknown';
}

sub crashplan_username {
    my ($path) = @_;
    $path ||= '/Library/Application Support/CrashPlan/.identity';
    open(my $identity, '<', $path) or return '';
    binmode $identity;
    while (my $line = <$identity>) {
        next unless $line =~ /\Ausername=(.*)\z/s;
        my $username = $1;
        $username =~ s/\s+\z//;
        close $identity;
        return decode('UTF-8', $username, FB_DEFAULT);
    }
    close $identity;
    return '';
}

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

sub _managed_uuid_in_object {
    my ($object) = @_;
    return unless blessed($object) && $$object;

    if ($object->isKindOfClass_(NSDictionary->class())) {
        my $keys = $object->keyEnumerator();
        while (my $key_object = $keys->nextObject()) {
            last unless blessed($key_object) && $$key_object;
            my $key = objc_string($key_object);
            my $value = $object->objectForKey_($key_object);
            if ($key =~ /managed[ _-]*user/i) {
                my $text = objc_string($value);
                return $1 if $text =~ /([0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12})/;
            }
            my $found = _managed_uuid_in_object($value);
            return $found if defined $found;
        }
        return;
    }

    if ($object->isKindOfClass_(NSArray->class())) {
        my $items = $object->objectEnumerator();
        while (my $item = $items->nextObject()) {
            last unless blessed($item) && $$item;
            my $found = _managed_uuid_in_object($item);
            return $found if defined $found;
        }
        return;
    }

    if ($object->isKindOfClass_(NSString->class())) {
        my $text = objc_string($object);
        return $1 if $text =~ /Managed\s+User\s*:\s*([0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12})/i;
    }
    return;
}

sub mdm_managed_user {
    my (%options) = @_;
    my ($ok, $output);
    if (defined $options{profile_output}) {
        ($ok, $output) = (1, $options{profile_output});
    } else {
        ($ok, $output) = run_command(
            {}, '/usr/sbin/system_profiler', '-xml',
            'SPConfigurationProfileDataType'
        );
    }
    return 'NONE' unless $ok;
    my $plist = parse_plist_output($output);
    my $uuid = _managed_uuid_in_object($plist);
    return 'NONE' unless defined $uuid;

    my ($search_ok, $search_output);
    if ($options{directory_search}) {
        ($search_ok, $search_output) = $options{directory_search}->($uuid);
    } else {
        ($search_ok, $search_output) = run_command(
            {}, '/usr/bin/dscl', '.', '-search', '/Users',
            'GeneratedUID', $uuid
        );
    }
    if ($search_ok && $search_output =~ /\A\s*([^\s]+)/) {
        return $1;
    }
    return $uuid;
}

sub physical_or_virtual {
    my (%options) = @_;
    my $snapshot = ref($options{hardware_snapshot}) eq 'HASH'
        ? $options{hardware_snapshot}
        : collect_hardware_snapshot(%options);
    return $snapshot->{is_virtual} ? 'virtual' : 'physical';
}

sub _plist_strings_for_key {
    my ($object, $wanted_key) = @_;
    return () unless blessed($object) && $$object;

    if ($object->isKindOfClass_(NSDictionary->class())) {
        my @matches;
        my $keys = $object->keyEnumerator();
        while (my $key_object = $keys->nextObject()) {
            last unless blessed($key_object) && $$key_object;
            my $value = $object->objectForKey_($key_object);
            if (objc_string($key_object) eq $wanted_key) {
                my $text = objc_string($value);
                push @matches, $text if length $text;
            }
            push @matches, _plist_strings_for_key($value, $wanted_key);
        }
        return @matches;
    }

    if ($object->isKindOfClass_(NSArray->class())) {
        my @matches;
        my $items = $object->objectEnumerator();
        while (my $item = $items->nextObject()) {
            last unless blessed($item) && $$item;
            push @matches, _plist_strings_for_key($item, $wanted_key);
        }
        return @matches;
    }
    return ();
}

sub _virtual_machine_type {
    my ($output) = @_;
    my $plist = parse_plist_output($output);
    return 'unknown_virtual' unless blessed($plist) && $$plist;

    my @boot_rom_versions = _plist_strings_for_key(
        $plist, 'boot_rom_version'
    );
    for my $version (@boot_rom_versions) {
        return 'vmware' if $version =~ /VMW/i;
    }
    for my $version (@boot_rom_versions) {
        return 'virtualbox' if $version =~ /VirtualBox/i;
    }

    my @ethernet_vendors = _plist_strings_for_key(
        $plist, 'spethernet_vendor-id'
    );
    for my $vendor (@ethernet_vendors) {
        return 'parallels' if $vendor =~ /0x1a(?:b8|f4)/i;
    }
    return 'unknown_virtual';
}

sub virtualization_facts {
    my (%options) = @_;
    my $snapshot = ref($options{hardware_snapshot}) eq 'HASH'
        ? $options{hardware_snapshot}
        : collect_hardware_snapshot(%options);
    if (!$snapshot->{is_virtual}) {
        return {
            physical_or_virtual => 'physical',
            machine_type => 'physical',
        };
    }

    my ($ok, $output);
    if ($options{profiler_probe}) {
        ($ok, $output) = $options{profiler_probe}->();
    } elsif (defined $options{profiler_output}) {
        ($ok, $output) = (1, $options{profiler_output});
    } else {
        ($ok, $output) = run_command(
            {}, '/usr/sbin/system_profiler', '-xml',
            'SPEthernetDataType', 'SPHardwareDataType'
        );
    }

    return {
        physical_or_virtual => 'virtual',
        machine_type => $ok
            ? _virtual_machine_type($output)
            : 'unknown_virtual',
    };
}

1;
