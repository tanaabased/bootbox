# Inputs Example

This example keeps lightweight coverage on the public `bootbox` interface. It validates help,
version, hidden probes, input precedence, token masking, and clean argument failures without running
the full bootstrap path.

## Setup

```bash
# should prepare the inputs scratch fixtures
rm -rf .tmp && mkdir -p .tmp/implicit && touch .tmp/implicit/Brewfile

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

# should keep internal external sudo controls out of help output
if bootbox --help | grep -F 'BOOTBOX_EXTERNAL_SUDO'; then exit 1; fi
if bootbox --help | grep -F -- '--external-sudo'; then exit 1; fi

# should print a version string
test -n "$(bootbox --version)"

# should reject force-interactive mode in CI
set +e
output="$(CI=1 INTERACTIVE=1 bootbox --help 2>&1)"
command_status="$?"
set -e
printf "%s\n" "$output"
printf "%s\n" "$output" | grep -F "cannot run force-interactive mode in CI."
test "$command_status" -ne 0

# should reject contradictory interactive controls
set +e
output="$(INTERACTIVE=1 NONINTERACTIVE=1 bootbox --help 2>&1)"
command_status="$?"
set -e
printf "%s\n" "$output"
printf "%s\n" "$output" | grep -F 'both $INTERACTIVE and $NONINTERACTIVE are set.'
test "$command_status" -ne 0

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

# should use no Brewfiles when neither an implicit default nor an environment input exists
bootbox --help | grep -F -- '--brewfile       installs brewfiles from local paths or URLs [default: none]'

# should discover an implicit Brewfile from the working directory
(cd .tmp/implicit && bootbox --help) | grep -F -- '--brewfile       installs brewfiles from local paths or URLs [default: ./Brewfile]'

# should let the public environment input override the implicit Brewfile
(cd .tmp/implicit && BOOTBOX_BREWFILE='Brewfile.env-one,Brewfile.env-two' bootbox --help) | grep -F -- '--brewfile       installs brewfiles from local paths or URLs [default: Brewfile.env-one,Brewfile.env-two]'

# should let repeated Brewfile options replace environment inputs
BOOTBOX_BREWFILE='Brewfile.env' bootbox --brewfile 'Brewfile.cli-one' --brewfile='Brewfile.cli-two' --help | grep -F -- '--brewfile       installs brewfiles from local paths or URLs [default: Brewfile.cli-one,Brewfile.cli-two]'

# should let inline empty Brewfile options clear environment inputs
BOOTBOX_BREWFILE='Brewfile.env' bootbox --brewfile= --help | grep -F -- '--brewfile       installs brewfiles from local paths or URLs [default: none]'
BOOTBOX_BREWFILE='Brewfile.env' bootbox --brewfiles= --help | grep -F -- '--brewfile       installs brewfiles from local paths or URLs [default: none]'

# should use no dotpackages by default
bootbox --help | grep -F -- '--dotpkg         stows dot packages into target [default: none]'

# should use dotpackages from the public environment input
BOOTBOX_DOTPKG='dotpkgs/env-one,dotpkgs/env-two' bootbox --help | grep -F -- '--dotpkg         stows dot packages into target [default: dotpkgs/env-one,dotpkgs/env-two]'

# should let repeated dotpackage options replace environment inputs
BOOTBOX_DOTPKG='dotpkgs/env' bootbox --dotpkg 'dotpkgs/cli-one' --dotpkg='dotpkgs/cli-two' --help | grep -F -- '--dotpkg         stows dot packages into target [default: dotpkgs/cli-one,dotpkgs/cli-two]'

# should let inline empty dotpackage options clear environment inputs
BOOTBOX_DOTPKG='dotpkgs/env' bootbox --dotpkg= --help | grep -F -- '--dotpkg         stows dot packages into target [default: none]'
BOOTBOX_DOTPKG='dotpkgs/env' bootbox --dotpkgs= --help | grep -F -- '--dotpkg         stows dot packages into target [default: none]'

# should use no SSH keys by default
bootbox --help | grep -F -- '--ssh-key        installs 1password ssh keys into target .ssh as vault/item[:filename] [default: none]'

# should use SSH keys from the public environment input
BOOTBOX_SSH_KEY='vault/env-one,vault/env-two:id_env_two' bootbox --help | grep -F -- '--ssh-key        installs 1password ssh keys into target .ssh as vault/item[:filename] [default: vault/env-one,vault/env-two:id_env_two]'

# should let repeated SSH key options replace environment inputs
BOOTBOX_SSH_KEY='vault/env' bootbox --ssh-key 'vault/cli-one' --ssh-key='vault/cli-two:id_cli_two' --help | grep -F -- '--ssh-key        installs 1password ssh keys into target .ssh as vault/item[:filename] [default: vault/cli-one,vault/cli-two:id_cli_two]'

# should let inline empty SSH key options clear environment inputs
BOOTBOX_SSH_KEY='vault/env' bootbox --ssh-key= --help | grep -F -- '--ssh-key        installs 1password ssh keys into target .ssh as vault/item[:filename] [default: none]'
BOOTBOX_SSH_KEY='vault/env' bootbox --ssh-keys= --help | grep -F -- '--ssh-key        installs 1password ssh keys into target .ssh as vault/item[:filename] [default: none]'

# should use HOME as the default target
HOME='/tmp/bootbox-input-home' bootbox --help | grep -F -- '--target         installs dotpkgs and identities relative to here [default: /tmp/bootbox-input-home]'

# should let the public environment input override the default target
HOME='/tmp/bootbox-input-home' BOOTBOX_TARGET='/tmp/bootbox-input-env-target' bootbox --help | grep -F -- '--target         installs dotpkgs and identities relative to here [default: /tmp/bootbox-input-env-target]'

# should let the target option override the environment input
BOOTBOX_TARGET='/tmp/bootbox-input-env-target' bootbox --target '/tmp/bootbox-input-cli-target' --help | grep -F -- '--target         installs dotpkgs and identities relative to here [default: /tmp/bootbox-input-cli-target]'

# should use no 1Password token by default
bootbox --help | grep -F -- '--op-token       auths with 1password service account token [default: none]'

# should fall back to the 1Password service account environment input and mask it
OP_SERVICE_ACCOUNT_TOKEN='fallback-service-secret' bootbox --help | grep -F -- '--op-token       auths with 1password service account token [default: fall...cret]'
if OP_SERVICE_ACCOUNT_TOKEN='fallback-service-secret' bootbox --help | grep -F 'fallback-service-secret'; then exit 1; fi

# should prefer and mask the public bootbox token environment input
OP_SERVICE_ACCOUNT_TOKEN='fallback-service-secret' BOOTBOX_OP_TOKEN='public-bootbox-secret' bootbox --help | grep -F -- '--op-token       auths with 1password service account token [default: publ...cret]'
if OP_SERVICE_ACCOUNT_TOKEN='fallback-service-secret' BOOTBOX_OP_TOKEN='public-bootbox-secret' bootbox --help | grep -F 'public-bootbox-secret'; then exit 1; fi

# should let the token option override the public environment input and keep it masked
BOOTBOX_OP_TOKEN='public-bootbox-secret' bootbox --op-token 'option-argument-secret' --help | grep -F -- '--op-token       auths with 1password service account token [default: opti...cret]'
if BOOTBOX_OP_TOKEN='public-bootbox-secret' bootbox --op-token 'option-argument-secret' --help | grep -F 'option-argument-secret'; then exit 1; fi

# should allow an inline empty token option to clear the environment input
BOOTBOX_OP_TOKEN='public-bootbox-secret' bootbox --op-token= --help | grep -F -- '--op-token       auths with 1password service account token [default: none]'

# should show disabled boolean defaults
bootbox --help | grep -F -- '--debug          shows debug messages [default: off]'
bootbox --help | grep -F -- '--quiet          suppresses bootbox status output [default: off]'
bootbox --help | grep -F -- '--no-sudo        disables sudo checks, prompts, and elevation [default: off]'
bootbox --help | grep -F -- '--force          forces supported overwrite operations [default: off]'

# should enable booleans from public environment inputs
BOOTBOX_DEBUG=1 bootbox --help | grep -F -- '--debug          shows debug messages [default: on]'
BOOTBOX_QUIET=1 bootbox --help | grep -F -- '--quiet          suppresses bootbox status output [default: on]'
BOOTBOX_NO_SUDO=1 bootbox --help | grep -F -- '--no-sudo        disables sudo checks, prompts, and elevation [default: on]'
BOOTBOX_FORCE=1 bootbox --help | grep -F -- '--force          forces supported overwrite operations [default: on]'

# should let boolean options override disabled environment inputs
BOOTBOX_DEBUG=0 bootbox --debug --help | grep -F -- '--debug          shows debug messages [default: on]'
BOOTBOX_QUIET=0 bootbox --quiet --help | grep -F -- '--quiet          suppresses bootbox status output [default: on]'
BOOTBOX_NO_SUDO=0 bootbox --no-sudo --help | grep -F -- '--no-sudo        disables sudo checks, prompts, and elevation [default: on]'
BOOTBOX_FORCE=0 bootbox --force --help | grep -F -- '--force          forces supported overwrite operations [default: on]'

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
