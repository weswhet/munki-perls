#!/usr/bin/perl
use 5.008008;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
package MunkiPerls::Condition::LocalUserDirs;
use MunkiPerls qw(perl_array run_condition);

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

unless (caller) {
    exit run_condition(\@ARGV, sub {
        return { local_user_dirs => perl_array(local_user_dirs()) };
    });
}
1;
