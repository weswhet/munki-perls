use 5.012;
use strict;
use warnings;

use File::Path qw(make_path);
use File::Temp qw(tempdir tempfile);
use Scalar::Util qw(blessed);
use Test::More;
use lib 'conditions/lib';
use Foundation;
use MunkiPerls qw(
    fact_array fact_bool fact_string foundation_array foundation_dictionary
    foundation_string load_plist_file objc_string write_facts
);

sub save_native {
    my ($path, $root, $format) = @_;
    my $data = NSPropertyListSerialization->dataWithPropertyList_format_options_error_(
        $root, $format, 0, undef
    );
    return $data->writeToFile_options_error_(foundation_string($path), 1, undef);
}

sub value_for {
    my ($plist, $key) = @_;
    return $plist->objectForKey_(foundation_string($key));
}

my $directory = tempdir(CLEANUP => 1);
my $absent = "$directory/absent.plist";
ok(write_facts($absent, { greeting => fact_string('hello') }), 'creates absent plist');
is(objc_string(value_for(load_plist_file($absent, dictionary => 1), 'greeting')),
    'hello', 'reads newly created XML plist');

my $binary = "$directory/binary.plist";
my $binary_root = foundation_dictionary();
$binary_root->setObject_forKey_(foundation_string('preserved'), foundation_string('old'));
ok(save_native($binary, $binary_root, 200), 'creates binary plist with Foundation');
ok(write_facts($binary, { new => fact_bool(1) }), 'merges binary input');
my $binary_result = load_plist_file($binary, dictionary => 1);
is(objc_string(value_for($binary_result, 'old')), 'preserved', 'preserves binary plist value');
is(value_for($binary_result, 'new')->objCType(), 'c', 'writes native boolean');

my $rich = "$directory/rich.plist";
my $rich_root = foundation_dictionary();
my $nested = foundation_dictionary();
$nested->setObject_forKey_(foundation_string('inside'), foundation_string('nested'));
$rich_root->setObject_forKey_($nested, foundation_string('dictionary'));
my $date = NSDate->dateWithTimeIntervalSince1970_(123456789);
$rich_root->setObject_forKey_($date, foundation_string('date'));
my ($raw_fh, $raw_path) = tempfile(DIR => $directory);
binmode $raw_fh;
print {$raw_fh} "\x01\x02\x03";
close $raw_fh;
my $raw_data = NSData->dataWithContentsOfFile_(foundation_string($raw_path));
$rich_root->setObject_forKey_($raw_data, foundation_string('data'));
ok(save_native($rich, $rich_root, 100), 'creates rich XML plist');
ok(write_facts($rich, {
    unicode => fact_string("J\x{00fc}rgen \x{1f680}"),
    enabled => fact_bool(0),
    names => fact_array('one', "\x{4e8c}"),
}), 'merges Unicode and typed facts');
my $rich_result = load_plist_file($rich, dictionary => 1);
is(objc_string(value_for($rich_result, 'unicode')), "J\x{00fc}rgen \x{1f680}", 'Unicode round trips');
is(value_for($rich_result, 'enabled')->objCType(), 'c', 'false remains a boolean');
ok(value_for($rich_result, 'names')->isKindOfClass_(NSArray->class()), 'array has native type');
ok(value_for($rich_result, 'dictionary')->isKindOfClass_(NSDictionary->class()), 'nested dictionary preserved');
cmp_ok(abs(value_for($rich_result, 'date')->timeIntervalSince1970() - 123456789), '<', 1, 'date preserved');
is(value_for($rich_result, 'data')->length(), 3, 'data preserved');

for my $case (
    [ malformed => 'this is not a plist' ],
    [ empty => '' ],
) {
    my $path = "$directory/$case->[0].plist";
    open(my $fh, '>', $path) or die $!;
    print {$fh} $case->[1];
    close $fh;
    ok(write_facts($path, { recovered => fact_string('yes') }), "$case->[0] plist is recovered");
    is(objc_string(value_for(load_plist_file($path, dictionary => 1), 'recovered')),
        'yes', "$case->[0] recovery is valid");
}

my $non_dictionary = "$directory/array-root.plist";
my $array_root = foundation_array();
$array_root->addObject_(foundation_string('unrelated'));
ok(save_native($non_dictionary, $array_root, 100), 'creates non-dictionary plist');
ok(write_facts($non_dictionary, { recovered => fact_string('yes') }), 'non-dictionary root is replaced');
ok(load_plist_file($non_dictionary, dictionary => 1), 'replacement root is a dictionary');

my $concurrent = "$directory/concurrent.plist";
my @children;
for my $number (1 .. 8) {
    my $pid = fork();
    die "fork failed" unless defined $pid;
    if ($pid == 0) {
        my $ok = eval {
            write_facts($concurrent, { "key$number" => fact_string("value$number") });
        };
        exit($ok ? 0 : 1);
    }
    push @children, $pid;
}
for my $pid (@children) {
    waitpid($pid, 0);
    is($?, 0, 'concurrent writer completed');
}
my $concurrent_result = load_plist_file($concurrent, dictionary => 1);
is($concurrent_result->count(), 8, 'sidecar locking preserves every concurrent update');

my $atomic = "$directory/atomic.plist";
write_facts($atomic, { first => fact_string('one') });
my $before_inode = (stat($atomic))[1];
write_facts($atomic, { second => fact_string('two') });
my $after_inode = (stat($atomic))[1];
isnt($after_inode, $before_inode, 'atomic Foundation write replaces the destination');

SKIP: {
    skip 'permission behavior is not meaningful as root', 1 if $> == 0;
    my $locked_directory = "$directory/no-write";
    make_path($locked_directory, { mode => 0500 });
    my $failure = eval {
        write_facts("$locked_directory/output.plist", { key => fact_string('value') });
        1;
    };
    ok(!$failure, 'permission failure is reported');
    chmod 0700, $locked_directory;
}

done_testing();
