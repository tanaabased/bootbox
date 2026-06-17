# Bootbox CLI Contract Example

This example keeps lightweight coverage on the public `bootbox` interface. It validates help,
version, hidden probes, option precedence display, token masking, and clean argument failures without
running the full bootstrap path.

## Setup

```bash
# should reset the example scratch directory
rm -rf .tmp && mkdir -p .tmp

# should have prepared bootbox on PATH
command -v bootbox >/dev/null
```

## Testing

```bash
# should show bootbox usage
bootbox --help | grep -F 'Usage:'
bootbox --help | grep -F '[NONINTERACTIVE=1]'
bootbox --help | grep -F '[CI=1]'
bootbox --help | grep -F '[BOOTBOX_*...]'
bootbox --help | grep -F 'bootbox [options]'

# should document public options
bootbox --help | grep -F -- '--brewfile'
bootbox --help | grep -F -- '--dotpkg'
bootbox --help | grep -F -- '--ssh-key'
bootbox --help | grep -F -- '--op-token'
bootbox --help | grep -F -- '--target'
bootbox --help | grep -F -- '--version'
bootbox --help | grep -F -- '--debug'
bootbox --help | grep -F -- '--quiet'
bootbox --help | grep -F -- '--no-sudo'
bootbox --help | grep -F -- '--force'
bootbox --help | grep -F -- '--yes'

# should document public environment variables
bootbox --help | grep -F 'BOOTBOX_BREWFILE same as --brewfile'
bootbox --help | grep -F 'BOOTBOX_DOTPKG   same as --dotpkg'
bootbox --help | grep -F 'BOOTBOX_SSH_KEY  same as --ssh-key'
bootbox --help | grep -F 'BOOTBOX_OP_TOKEN same as --op-token; falls back to OP_SERVICE_ACCOUNT_TOKEN'
bootbox --help | grep -F 'BOOTBOX_TARGET   same as --target'
bootbox --help | grep -F 'BOOTBOX_FORCE    same as --force'
bootbox --help | grep -F 'BOOTBOX_QUIET    same as --quiet'
bootbox --help | grep -F 'BOOTBOX_NO_SUDO  same as --no-sudo'
bootbox --help | grep -F 'BOOTBOX_DEBUG    same as --debug'
bootbox --help | grep -F 'NONINTERACTIVE   same as --yes'
bootbox --help | grep -F 'CI               runs in CI mode and disables prompts'

# should not document legacy environment variables
if bootbox --help | grep -F 'TANAAB_'; then exit 1; fi

# should not expose a CI option
if bootbox --help | grep -F -- '--ci'; then exit 1; fi

# should keep the hidden core check out of help output
if bootbox --help | grep -F -- '--check-core'; then exit 1; fi

# should print a version string
test -n "$(bootbox --version)"

# should expose the hidden core check as a quiet 0/1 exit status
bootbox --check-core > .tmp/check-core.log 2>&1 || test "$?" -eq 1
test ! -s .tmp/check-core.log

# should describe the hidden core check when debug logging is enabled
bootbox --debug --check-core > .tmp/check-core-debug.log 2>&1 || test "$?" -eq 1
grep -F 'running hidden --check-core mode' .tmp/check-core-debug.log

# should keep debug logging on stderr when quiet mode is enabled
bootbox --quiet --debug --check-core > .tmp/check-core-quiet.stdout 2> .tmp/check-core-quiet.stderr || test "$?" -eq 1
test ! -s .tmp/check-core-quiet.stdout
grep -F 'running hidden --check-core mode' .tmp/check-core-quiet.stderr

# should mask token defaults in help
BOOTBOX_OP_TOKEN='secret-example-value' bootbox --help | grep -F 'secr...alue'
if BOOTBOX_OP_TOKEN='secret-example-value' bootbox --help | grep -F 'secret-example-value'; then exit 1; fi

# should allow an inline empty op token to mean no token
BOOTBOX_OP_TOKEN='secret-example-value' bootbox --op-token= --help | grep -F -- '--op-token       auths with 1password service account token [default: none]'

# should show debug, quiet, no-sudo, and force defaults
bootbox --help | grep -F -- '--debug          shows debug messages [default: off]'
bootbox --debug --help | grep -F -- '--debug          shows debug messages [default: on]'
bootbox --help | grep -F -- '--quiet          suppresses bootbox status output [default: off]'
bootbox --quiet --help | grep -F -- '--quiet          suppresses bootbox status output [default: on]'
BOOTBOX_QUIET=1 bootbox --help | grep -F -- '--quiet          suppresses bootbox status output [default: on]'
bootbox --help | grep -F -- '--no-sudo        disables sudo checks, prompts, and elevation [default: off]'
bootbox --no-sudo --help | grep -F -- '--no-sudo        disables sudo checks, prompts, and elevation [default: on]'
BOOTBOX_NO_SUDO=1 bootbox --help | grep -F -- '--no-sudo        disables sudo checks, prompts, and elevation [default: on]'
bootbox --help | grep -F -- '--force          forces supported overwrite operations [default: off]'
bootbox --force --help | grep -F -- '--force          forces supported overwrite operations [default: on]'

# should let inline empty brewfile values clear env defaults
BOOTBOX_BREWFILE='Brewfile.example' bootbox --brewfile= --help | grep -F -- '--brewfile       installs brewfiles from local paths or URLs [default: none]'
BOOTBOX_BREWFILE='Brewfile.example' bootbox --brewfiles= --help | grep -F -- '--brewfile       installs brewfiles from local paths or URLs [default: none]'

# should let inline empty dotpkg values clear env defaults
BOOTBOX_DOTPKG='dotpkgs/git' bootbox --dotpkg= --help | grep -F -- '--dotpkg         stows dot packages into target [default: none]'
BOOTBOX_DOTPKG='dotpkgs/git' bootbox --dotpkgs= --help | grep -F -- '--dotpkg         stows dot packages into target [default: none]'

# should let inline empty ssh key values clear env defaults
BOOTBOX_SSH_KEY='vault/item' bootbox --ssh-key= --help | grep -F -- '--ssh-key        installs 1password ssh keys into target .ssh as vault/item[:filename] [default: none]'
BOOTBOX_SSH_KEY='vault/item' bootbox --ssh-keys= --help | grep -F -- '--ssh-key        installs 1password ssh keys into target .ssh as vault/item[:filename] [default: none]'

# should fail cleanly when a separated value is missing
! bootbox --brewfile > .tmp/missing-brewfile.log 2>&1
grep -F 'error: option --brewfile requires a value.' .tmp/missing-brewfile.log
grep -F 'Usage:' .tmp/missing-brewfile.log
! bootbox --op-token > .tmp/missing-op-token.log 2>&1
grep -F 'error: option --op-token requires a value.' .tmp/missing-op-token.log
! bootbox --target > .tmp/missing-target.log 2>&1
grep -F 'error: option --target requires a value.' .tmp/missing-target.log

# should reject an empty target value
! bootbox --target= > .tmp/empty-target.log 2>&1
grep -F 'error: option --target must not be empty.' .tmp/empty-target.log

# should fail for an unknown option with usage context
! bootbox --definitely-bogus > .tmp/invalid.log 2>&1
grep -F 'error: unrecognized option' .tmp/invalid.log
grep -F 'Usage:' .tmp/invalid.log
```

## Destroy tests

```bash
# should remove the example scratch directory
rm -rf .tmp
```
