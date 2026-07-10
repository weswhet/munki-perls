#!/usr/bin/perl
use 5.008008;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
package MunkiPerls::Condition::AdminUsers;
use MunkiPerls qw(fact_array run_condition);

sub admin_users {
    my (undef, undef, undef, $members) = getgrnam('admin');
    return () unless defined $members && length $members;
    return sort grep { length $_ } split /\s+/, $members;
}

unless (caller) {
    exit run_condition(\@ARGV, sub {
        return { admin_users => fact_array(admin_users()) };
    });
}
1;
