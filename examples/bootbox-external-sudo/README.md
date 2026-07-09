# Bootbox External Sudo Example

This example verifies the hidden `BOOTBOX_EXTERNAL_SUDO=1` wrapper contract with example-local fake
`sudo`, `brew`, and `stow` binaries. It keeps the production script hard-coded to `/usr/bin/sudo`,
then patches only an example-local copy so the tests can observe credential checks, noninteractive
sudo, and invalidation behavior without touching real machine sudo state.

## Setup

```bash
# should prepare an example-local bootbox copy with fake sudo
rm -rf .tmp && mkdir -p .tmp
fake_sudo="$(pwd)/bin/sudo"
sed "s|/usr/bin/sudo|$fake_sudo|g" "$(command -v bootbox)" > .tmp/bootbox
chmod +x .tmp/bootbox
```

## Testing

```bash
# should use caller-owned sudo for privileged external mode
bin/run-bootbox external-valid 2>&1 | tee /dev/stderr | awk '/please enter sudo password:/ { found=1 } END { exit found }'
test -f .tmp/sudo-state/validated
test -f .tmp/sudo-state/privileged_mkdir
test ! -e .tmp/sudo-state/interactive
test ! -e .tmp/sudo-state/invalidated

# should fail before mutation when external sudo credential is unavailable
{ ! bin/run-bootbox external-invalid; } 2>&1 | tee /dev/stderr | awk '
  /bootbox external sudo mode requires an active sudo credential[.]/ { message=1 }
  /sudo -v/ { remediation=1 }
  /please enter sudo password:/ { prompt=1 }
  END { if (message && remediation && !prompt) exit 0; exit 1 }
'
test -f .tmp/sudo-state/validated
test ! -e .tmp/sudo-state/unexpected

# should skip sudo validation when external mode does not need sudo
bin/run-bootbox external-writable 2>&1 | tee /dev/stderr | awk '/please enter sudo password:/ { found=1 } END { exit found }'
test ! -e .tmp/sudo-state/unexpected

# should suppress standalone password message with cached credential
bin/run-bootbox standalone-cached 2>&1 | tee /dev/stderr | awk '/please enter sudo password:/ { found=1 } END { exit found }'
test -f .tmp/sudo-state/validated

# should preserve standalone cold-cache sudo flow
bin/run-bootbox standalone-cold 2>&1 | tee /dev/stderr | grep -F 'please enter sudo password:'
test -f .tmp/sudo-state/prompted
test -f .tmp/sudo-state/invalidated

# should reject contradictory sudo modes
{ ! bin/run-bootbox conflict; } 2>&1 | tee /dev/stderr | grep -F 'BOOTBOX_EXTERNAL_SUDO=1 cannot be combined with --no-sudo or BOOTBOX_NO_SUDO=1.'
test ! -e .tmp/sudo-state/unexpected

# should preserve no-sudo failure behavior when elevation is required
{ ! bin/run-bootbox no-sudo; } 2>&1 | tee /dev/stderr | grep -F 'bootbox is running with --no-sudo'
test ! -e .tmp/sudo-state/unexpected
```

## Destroy tests

```bash
# should remove the example scratch directory
rm -rf .tmp
```
