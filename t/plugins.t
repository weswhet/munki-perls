use 5.008008;
use strict;
use warnings;

use File::Basename qw(basename);
use File::Path qw(mkpath);
use File::Temp qw(tempdir);
use Scalar::Util qw(blessed);
use Test::More 'no_plan';
use lib 'conditions/lib';
use Foundation;
use MunkiPerls qw(foundation_string load_plist_file objc_string);
use MunkiPerls::Plugins qw(
    collect_plugins discover_plugins load_plugin run_plugins_condition
);

sub write_plugin {
    my ($directory, $name, $source, $mode) = @_;
    my $path = "$directory/$name";
    open(my $handle, '>', $path) or die $!;
    print {$handle} $source;
    close $handle or die $!;
    chmod(defined($mode) ? $mode : 0644, $path) or die $!;
    return $path;
}

my $directory = tempdir(CLEANUP => 1);
chmod 0700, $directory or die $!;

my $first = write_plugin($directory, '00_first.pl', <<'PLUGIN');
use 5.008008;
use strict;
use warnings;
use MunkiPerls qw(perl_string);
sub helper_name { return 'first' }
sub perls {
    my ($context) = @_;
    return {
        collision => perl_string('first'),
        context_path => perl_string($context->{output_path}),
    };
}
1;
PLUGIN

my $types = write_plugin($directory, '10_types.pl', <<'PLUGIN');
use 5.008008;
use strict;
use warnings;
use MunkiPerls qw(
    perl_array perl_bool perl_dictionary perl_integer perl_real perl_string
);
sub perls {
    return {
        enabled => perl_bool(1),
        integer => perl_integer(42),
        mixed => perl_array(
            'plain string',
            perl_integer(7),
            perl_dictionary(nested => perl_bool(0)),
        ),
        multi_key => perl_string('present'),
        nested => perl_dictionary(
            label => 'west',
            ratio => perl_real('1.25'),
        ),
        real => perl_real('3.5'),
    };
}
1;
PLUGIN

write_plugin($directory, '20_invalid.pl', <<'PLUGIN');
use 5.008008;
use strict;
use warnings;
use MunkiPerls qw(perl_string);
sub perls {
    return {
        invalid => { type => 'unsupported', value => 'no' },
        rejected_with_plugin => perl_string('no'),
    };
}
1;
PLUGIN

write_plugin($directory, '30_runtime.pl', <<'PLUGIN');
use 5.008008;
use strict;
use warnings;
sub perls { die "collector exploded\n" }
1;
PLUGIN

write_plugin($directory, '40_missing_interface.pl', <<'PLUGIN');
use 5.008008;
use strict;
use warnings;
1;
PLUGIN

write_plugin($directory, '50_syntax.pl', "use strict; this is not perl;\n");

my $last = write_plugin($directory, '60_last.pl', <<'PLUGIN');
use 5.008008;
use strict;
use warnings;
use MunkiPerls qw(perl_string);
sub helper_name { return 'last' }
sub perls { return { collision => perl_string('last') } }
1;
PLUGIN

write_plugin($directory, '70_empty.pl', <<'PLUGIN');
use 5.008008;
use strict;
use warnings;
sub perls { return {} }
1;
PLUGIN

write_plugin($directory, '.hidden.pl', "sub perls { return {} }\n1;\n");
write_plugin($directory, 'notes.txt', "not a plugin\n");
write_plugin(
    $directory,
    '80_unsafe.pl',
    "sub perls { return {} }\n1;\n",
    0666,
);
mkpath("$directory/90_directory.pl", 0, 0755);
symlink($first, "$directory/95_symlink.pl") or die $!;

my @discovery_diagnostics;
my @discovered = discover_plugins(
    $directory,
    diagnostic => sub { push @discovery_diagnostics, @_ },
);
is_deeply(
    [map { basename($_) } @discovered],
    [qw(
        00_first.pl
        10_types.pl
        20_invalid.pl
        30_runtime.pl
        40_missing_interface.pl
        50_syntax.pl
        60_last.pl
        70_empty.pl
    )],
    'discovery is sorted and includes only safe regular Perl files'
);
like(
    join("\n", @discovery_diagnostics),
    qr{80_unsafe\.pl.*writable by group or others},
    'unsafe permissions are diagnosed'
);
like(
    join("\n", @discovery_diagnostics),
    qr{90_directory\.pl.*not a regular file},
    'plugin-shaped directories are diagnosed'
);
like(
    join("\n", @discovery_diagnostics),
    qr{95_symlink\.pl.*symbolic link},
    'symlinks are diagnosed'
);

my @diagnostics;
my $output_path = "$directory/collected.plist";
my $perls = collect_plugins(
    $directory,
    { output_path => $output_path },
    diagnostic => sub { push @diagnostics, @_ },
    verbose => 1,
);
is($perls->{collision}->{value}, 'last', 'later sorted plugins replace keys');
is(
    $perls->{context_path}->{value},
    $output_path,
    'plugins receive the runner context'
);
is($perls->{integer}->{value}, 42, 'integer descriptors are collected');
is($perls->{real}->{value}, 3.5, 'real descriptors are collected');
ok(exists $perls->{multi_key}, 'one plugin can return multiple keys');
ok(!exists $perls->{invalid}, 'invalid plugin output is rejected');
ok(
    !exists $perls->{rejected_with_plugin},
    'validation failure rejects the entire plugin result'
);
like(
    join("\n", @diagnostics),
    qr{60_last\.pl replaces collision from 00_first\.pl},
    'verbose diagnostics identify deterministic overrides'
);
like(
    join("\n", @diagnostics),
    qr{20_invalid\.pl returned invalid perls},
    'invalid output is diagnosed'
);
like(
    join("\n", @diagnostics),
    qr{30_runtime\.pl failed to collect: collector exploded},
    'runtime failures are isolated and diagnosed'
);
like(
    join("\n", @diagnostics),
    qr{40_missing_interface\.pl failed to load: plugin does not define perls},
    'missing interfaces are diagnosed'
);
like(
    join("\n", @diagnostics),
    qr{50_syntax\.pl failed to load:},
    'syntax failures are isolated and diagnosed'
);

my $first_plugin = load_plugin($first);
my $last_plugin = load_plugin($last);
isnt(
    $first_plugin->{package},
    $last_plugin->{package},
    'each plugin receives an isolated generated package'
);
is(
    $first_plugin->{package}->can('helper_name')->(),
    'first',
    'first plugin helpers remain isolated'
);
is(
    $last_plugin->{package}->can('helper_name')->(),
    'last',
    'later plugin helpers do not replace earlier helpers'
);

my $only_output = "$directory/only.plist";
my @only_arguments = ('--output', $only_output, '--only', '00_first');
my $only_stderr = '';
my $only_status;
{
    local *STDERR;
    open(STDERR, '>', \$only_stderr) or die $!;
    $only_status = run_plugins_condition(
        \@only_arguments,
        plugin_dir => $directory,
    );
}
is(
    $only_status,
    0,
    '--only accepts a plugin filename stem'
);
my $only_plist = load_plist_file($only_output, dictionary => 1);
is($only_plist->count(), 2, '--only writes only the selected plugin keys');
is(
    objc_string(
        $only_plist->objectForKey_(foundation_string('collision'))
    ),
    'first',
    '--only runs the selected plugin'
);

my @missing_arguments = (
    '--output', "$directory/missing.plist", '--only', 'not_here'
);
my $missing_stderr = '';
my $missing_status;
{
    local *STDERR;
    open(STDERR, '>', \$missing_stderr) or die $!;
    $missing_status = run_plugins_condition(
        \@missing_arguments,
        plugin_dir => $directory,
    );
}
is($missing_status, 1, 'a missing --only plugin fails');
like($missing_stderr, qr{Plugin not found}, 'missing plugin error is reported');

my $missing_directory = "$directory/not-a-directory";
my $missing_error = eval { discover_plugins($missing_directory); 1 };
ok(!$missing_error, 'a missing plugin directory is fatal');
like($@, qr{Plugin directory is missing}, 'missing directory is identified');

chmod 0777, $directory or die $!;
my $unsafe_directory = eval { discover_plugins($directory); 1 };
ok(!$unsafe_directory, 'an unsafe plugin directory is fatal');
like($@, qr{Plugin directory is writable}, 'unsafe directory is identified');
chmod 0700, $directory or die $!;
