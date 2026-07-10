use 5.008008;
use strict;
use warnings;
use Scalar::Util qw(blessed);
use Foundation;
use MunkiPerls qw(
    foundation_string load_plist_file objc_string perl_array
);

sub _valid_object {
    my ($object) = @_;
    return blessed($object) && $$object;
}

sub system_extensions {
    my ($database_path) = @_;
    $database_path ||= '/Library/SystemExtensions/db.plist';

    my $database = load_plist_file($database_path, dictionary => 1);
    return () unless _valid_object($database);

    my $extensions = eval {
        $database->objectForKey_(foundation_string('extensions'));
    };
    return () unless _valid_object($extensions)
        && $extensions->isKindOfClass_(NSArray->class());

    my %enabled;
    for (my $index = 0; $index < $extensions->count(); $index++) {
        my $row = eval { $extensions->objectAtIndex_($index) };
        next unless _valid_object($row)
            && $row->isKindOfClass_(NSDictionary->class());

        my $state = eval {
            $row->objectForKey_(foundation_string('state'));
        };
        next unless _valid_object($state)
            && $state->isKindOfClass_(NSString->class())
            && objc_string($state) eq 'activated_enabled';

        my $identifier = eval {
            $row->objectForKey_(foundation_string('identifier'));
        };
        next unless _valid_object($identifier)
            && $identifier->isKindOfClass_(NSString->class());
        my $bundle_id = objc_string($identifier);
        $enabled{$bundle_id} = 1 if length $bundle_id;
    }

    return sort keys %enabled;
}

sub perls {
    return {
        system_extensions => perl_array(system_extensions()),
    };
}
1;
