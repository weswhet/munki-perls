package MunkiPerls::Plugins;

use 5.008008;
use strict;
use warnings;

use Exporter qw(import);
use File::Basename qw(basename);
use File::Spec;
use Getopt::Long qw(GetOptions);

use MunkiPerls qw(
    managed_install_dir validate_perls write_perls
);

our @EXPORT_OK = qw(
    collect_plugins discover_plugins load_plugin run_plugins_condition
);
our $LOAD_SEQUENCE = 0;

sub _owner_uid {
    return $> == 0 ? 0 : $>;
}

sub _safe_path {
    my ($path, $kind) = @_;
    my @metadata = lstat($path);
    die "$kind is missing: $path\n" unless @metadata;
    die "$kind must not be a symbolic link: $path\n" if -l _;
    if ($kind eq 'Plugin directory') {
        die "$kind is not a directory: $path\n" unless -d _;
    } else {
        die "$kind is not a regular file: $path\n" unless -f _;
    }
    die "$kind has an unsafe owner: $path\n"
        unless $metadata[4] == _owner_uid();
    die "$kind is writable by group or others: $path\n"
        if ($metadata[2] & 0022);
    return 1;
}

sub discover_plugins {
    my ($directory, %options) = @_;
    my $diagnostic = $options{diagnostic} || sub { };
    _safe_path($directory, 'Plugin directory');

    opendir(my $handle, $directory)
        or die "Cannot read plugin directory: $directory\n";
    my @names = sort grep {
        $_ !~ /\A\./ && $_ =~ /\.pl\z/
    } readdir($handle);
    closedir $handle or die "Cannot close plugin directory: $directory\n";

    my @paths;
    for my $name (@names) {
        my $path = File::Spec->catfile($directory, $name);
        my $safe = eval { _safe_path($path, 'Plugin') };
        if (!$safe) {
            $diagnostic->(
                "plugin $name skipped: " . _diagnostic_text($@)
            );
            next;
        }
        push @paths, $path;
    }
    return @paths;
}

sub _quoted_path {
    my ($path) = @_;
    $path =~ s/\\/\\\\/g;
    $path =~ s/'/\\'/g;
    return $path;
}

sub load_plugin {
    my ($path) = @_;
    $path = File::Spec->rel2abs($path);
    _safe_path($path, 'Plugin');
    my $package = 'MunkiPerls::LoadedPlugin::P' . ++$LOAD_SEQUENCE;
    my $quoted = _quoted_path($path);
    my $loaded = eval "package $package; do '$quoted'";
    my $error = $@;
    if (!defined $loaded) {
        $error ||= $! || 'plugin returned an undefined value';
        die "$error\n";
    }
    die "plugin returned false while loading\n" unless $loaded;
    my $callback = $package->can('perls');
    die "plugin does not define perls()\n" unless $callback;
    return {
        callback => $callback,
        name => basename($path),
        package => $package,
        path => $path,
    };
}

sub _diagnostic_text {
    my ($error) = @_;
    $error = 'unknown error' unless defined($error) && length($error);
    $error =~ s/[\r\n]+/ /g;
    $error =~ s/\s+\z//;
    return $error;
}

sub collect_plugins {
    my ($directory, $context, %options) = @_;
    $context ||= {};
    my $diagnostic = $options{diagnostic} || sub { };
    my $only = $options{only};
    if (defined $only) {
        die "Plugin name must not contain a path separator\n"
            if $only =~ m{[/\\]};
        $only .= '.pl' unless $only =~ /\.pl\z/;
    }

    my @paths = discover_plugins(
        $directory,
        diagnostic => $diagnostic,
    );
    if (defined $only) {
        @paths = grep { basename($_) eq $only } @paths;
        die "Plugin not found: $only\n" unless @paths;
    }

    my %merged;
    my %owners;
    for my $path (@paths) {
        my $name = basename($path);
        my $plugin = eval { load_plugin($path) };
        if (!$plugin) {
            $diagnostic->(
                "plugin $name failed to load: " . _diagnostic_text($@)
            );
            next;
        }

        my $perls = eval { $plugin->{callback}->($context) };
        if (!$perls || $@) {
            $diagnostic->(
                "plugin $name failed to collect: " . _diagnostic_text($@)
            );
            next;
        }
        my $valid = eval { validate_perls($perls) };
        if (!$valid) {
            $diagnostic->(
                "plugin $name returned invalid perls: "
                    . _diagnostic_text($@)
            );
            next;
        }

        for my $key (sort keys %{$perls}) {
            if (exists $merged{$key} && $options{verbose}) {
                $diagnostic->(
                    "plugin $name replaces $key from $owners{$key}"
                );
            }
            $merged{$key} = $perls->{$key};
            $owners{$key} = $name;
        }
    }
    return \%merged;
}

sub _usage {
    my ($program) = @_;
    return "Usage: $program [--output PATH] [--only NAME] [--verbose] [--help]\n";
}

sub run_plugins_condition {
    my ($argv, %options) = @_;
    my $output;
    my $only;
    my $verbose = 0;
    my $help = 0;
    my @args = @{$argv};
    my $ok;
    {
        local @ARGV = @args;
        $ok = GetOptions(
            'output=s' => \$output,
            'only=s' => \$only,
            'verbose' => \$verbose,
            'help' => \$help,
        );
        @args = @ARGV;
    }
    if (!$ok || @args) {
        print STDERR _usage($0);
        return 2;
    }
    if ($help) {
        print _usage($0);
        return 0;
    }

    $output ||= File::Spec->catfile(
        managed_install_dir(), 'ConditionalItems.plist'
    );
    my $debug = $verbose || ($ENV{MUNKI_PERLS_DEBUG} || '') eq '1';
    my $diagnostic = sub {
        print STDERR "munki-perls: $_[0]\n";
    };
    $diagnostic->('collecting plugins') if $debug;

    my $perls = eval {
        collect_plugins(
            $options{plugin_dir},
            { output_path => $output },
            diagnostic => $diagnostic,
            only => $only,
            verbose => $debug,
        );
    };
    if (!$perls || $@) {
        $diagnostic->('plugin collection failed: ' . _diagnostic_text($@));
        return 1;
    }
    my $saved = eval { write_perls($output, $perls) };
    if (!$saved || $@) {
        $diagnostic->('plist update failed: ' . _diagnostic_text($@));
        return 1;
    }
    $diagnostic->('perls saved') if $debug;
    return 0;
}

1;
