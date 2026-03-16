# Bootbox CLI Contract Example

This example keeps coverage on the shell-facing contract of `bootbox`: help output, version output,
and a clear failure for unknown options.

## Setup

```bash
# should reset the example scratch directory
rm -rf .tmp && mkdir -p .tmp
```

## Testing

```bash
# should show the brewfile flag in help output
bootbox --help | grep -- '--brewfile'

# should show the dotpkg env var in help output
bootbox --help | grep -- 'TANAAB_DOTPKG'

# should show the invoked command name in usage output
bootbox --help | grep -E 'Usage: .*bootbox '

# should keep the hidden core check out of help output
! bootbox --help | grep -- '--check-core'

# should print a version string
test -n "$(bootbox --version)"

# should expose the hidden core check as a quiet 0/1 exit status
bootbox --check-core > .tmp/check-core.log 2>&1 || test "$?" -eq 1
test ! -s .tmp/check-core.log

# should describe the hidden core check when debug logging is enabled
bootbox --debug --check-core > .tmp/check-core-debug.log 2>&1 || test "$?" -eq 1
grep -F 'running hidden --check-core mode' .tmp/check-core-debug.log

# should fail for an unknown option
! bootbox --definitely-bogus > .tmp/invalid.log 2>&1

# should explain the unknown option failure
grep -F 'Unrecognized option' .tmp/invalid.log
```

## Destroy tests

```bash
# should remove the example scratch directory
rm -rf .tmp
```
