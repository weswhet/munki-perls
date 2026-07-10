# munki-perls

`munki-perls` is a Perl 5.12-compatible collection of Munki
[admin-provided conditions](https://github.com/munki/munki/wiki/Conditional-Items).
It continues the fact collection found in `munki-facts` at commit
`a22a02a0304a`, retaining the established fact names and value semantics. This
is, naturally, the most direct route from facts to a property list.

The condition scripts support OS X 10.7 Lion and newer. They use Apple's stock
`Foundation` and `PerlObjCBridge` modules for every property-list operation and
write typed values to Munki's `ConditionalItems.plist`. Updates are serialized
with a stable sidecar lock and use Foundation's atomic file replacement, so
concurrently running condition scripts do not discard one another's facts. The
result should be pleasantly uneventful.

## Fact contract

The 11 executable scripts provide exactly these 22 keys. Munki does appreciate
the paperwork being in order.

| Key | Native plist type |
| --- | --- |
| `admin_users` | array of strings |
| `backtomymac_configured` | boolean |
| `bigsur_upgrade_supported` | boolean |
| `catalina_upgrade_supported` | boolean |
| `console_user` | string |
| `console_user_logged_in` | boolean |
| `crashplan_username` | string |
| `filevault_status` | string |
| `gatekeeper_status` | string |
| `goldengate_upgrade_supported` | boolean |
| `local_user_dirs` | array of strings |
| `machine_type` | string (`physical`, `vmware`, `virtualbox`, `parallels`, or `unknown_virtual`) |
| `mdm_managed_user` | string |
| `mojave_upgrade_supported` | boolean |
| `monterey_upgrade_supported` | boolean |
| `physical_or_virtual` | string (`physical` or `virtual`) |
| `sequoia_upgrade_supported` | boolean |
| `sierra_upgrade_supported` | boolean |
| `sip_status` | string |
| `sonoma_upgrade_supported` | boolean |
| `tahoe_upgrade_supported` | boolean |
| `ventura_upgrade_supported` | boolean |

`machine_type` intentionally replaces Munki's built-in `laptop`/`desktop`
value with the vendor-aware domain above. This is the historical collision,
now documented instead of merely surprising. Community facts remain unbundled
for now; twenty-two keys should keep the property list adequately occupied.

## Installation and use

Install the contents of `conditions/` into
`/usr/local/munki/conditions`, preserving executable modes on the 11 `.pl`
files. Munki runs each executable and merges its facts into the configured
`ManagedInstallDir/ConditionalItems.plist`.

Every condition accepts `--output PATH`, `--verbose`, and `--help`. The output
override is useful for testing. `MUNKI_PERLS_DEBUG=1` enables the same concise,
value-free diagnostics as `--verbose`; diagnostics never print usernames or
fact values.

```sh
/usr/local/munki/conditions/macos_upgrade_supported.pl --verbose
```

Missing commands on older systems yield the established `Unknown` or `NONE`
fallback and allow the remaining scripts to continue with their day. Back to
My Mac is queried directly through `scutil` only on Mojave and older and is
always false on Catalina and newer. Sierra accepts eligible source systems from
10.7–10.11 using the final model and board tables from the parent of
`munki-facts` removal commit `bbeee28dd2a5`; Mojave accepts 10.7–10.13, and
Catalina accepts 10.9–10.14.
Every upgrade check rejects a system already at or above the target before
considering virtual-machine eligibility.

## Maintainer tools

`tools/extract_supported_devices.pl` reads an installer asset plist with
Foundation, validates and deduplicates `SupportedDeviceModels`, and prints a
sorted Perl `qw(...)` table.

`tools/build-pkg.pl` stages the payload with native Perl file APIs and invokes
only `/usr/bin/pkgbuild`. It creates the unsigned
`munki-perls-0.1.0.pkg`, identifier `com.github.weswhet.munki-perls`, installed
at `/usr/local/munki/conditions`, with as little ceremony as the format permits:

```sh
tools/build-pkg.pl --verbose
```

Pass `--version X.Y.Z` to set both the package metadata and default artifact
name. After both CI architectures pass, every push to `main` uses the workflow
run number to build version `0.1.N`, creates tag `v0.1.N`, and publishes the
package on a GitHub Release. Re-running the workflow replaces the existing
asset rather than attempting to improve arithmetic.

## Verification and release validation

Run the syntax and test suites with Apple's Perl:

```sh
find conditions tools -type f \( -name '*.pl' -o -name '*.pm' \) -exec /usr/bin/perl -Iconditions/lib -c {} \;
/usr/bin/prove -lr t
```

A successful run is expected to be thoroughly boring.

CI covers ARM on `macos-15` and Intel on `macos-26-intel`; injected OS and
hardware fixtures exercise earlier macOS branches. Before a release, also
smoke-test the installed package on real or virtual Lion, Mountain Lion,
Mavericks, Yosemite, El Capitan, Sierra, High Sierra, and Mojave systems.
Confirm that each script runs under the bundled `/usr/bin/perl`, all 22 types
are native plist types, and existing Munki values survive an update.

## License and attribution

Licensed under Apache License 2.0. Hardware compatibility tables and original
fact behavior follow the `munki-facts` lineage described above.
