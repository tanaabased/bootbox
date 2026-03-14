# Bootbox CLI Contract Example

This example keeps coverage on the shell-facing contract of `bootbox.sh`: help output, version
output, and a clear failure for unknown options.

## Setup

```bash
# should reset the example scratch directory
rm -rf .tmp && mkdir -p .tmp
```

## Testing

```bash
# should show the brewfile flag in help output
bootbox.sh --help | grep -- '--brewfile'

# should show the dotpkg env var in help output
bootbox.sh --help | grep -- 'TANAAB_DOTPKG'

# should print a version string
test -n "$(bootbox.sh --version)"

# should fail for an unknown option
! bootbox.sh --definitely-bogus > .tmp/invalid.log 2>&1

# should explain the unknown option failure
grep -F 'Unrecognized option' .tmp/invalid.log
```

## Destroy tests

```bash
# should remove the example scratch directory
rm -rf .tmp
```
