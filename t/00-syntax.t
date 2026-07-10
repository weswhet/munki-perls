use 5.012;
use strict;
use warnings;

use File::Find;
use Test::More;

my @files;
find(
    sub {
        push @files, $File::Find::name
            if -f $_ && /\.(?:pl|pm)\z/;
    },
    'conditions', 'tools'
);

for my $file (sort @files) {
    my $status = system {
        '/usr/bin/perl'
    } '/usr/bin/perl', '-Iconditions/lib', '-c', $file;
    is($status, 0, "$file compiles");
}

done_testing();
