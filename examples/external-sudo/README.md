# External Sudo Example

This example exercises `bootbox` sudo behavior against a disposable macOS runner with real
Homebrew, Stow, users, permissions, and sudo state. It verifies caller-managed sudo, standalone
administrator detection, and strict no-sudo execution through observable package and filesystem
changes.

## Setup

```bash
# should prepare the real bootbox core toolchain
bootbox --brewfile=
bootbox --check-core

# should prepare privileged and unprivileged runner targets
mkdir -p "$TMPDIR/bootbox-external-sudo"
sudo mkdir -p \
  "$TMPDIR/bootbox-external-sudo/root-target" \
  "/private/tmp/bootbox-external-sudo/denied-target" \
  "/private/tmp/bootbox-external-sudo/nobody/home" \
  "/private/tmp/bootbox-external-sudo/nobody/tmp" \
  "/private/tmp/bootbox-external-sudo/nobody/dotpkgs"
sudo cp "$(command -v bootbox)" "/private/tmp/bootbox-external-sudo/bootbox"
sudo cp -R dotpkgs/git "/private/tmp/bootbox-external-sudo/nobody/dotpkgs/git"
sudo chown -R nobody "/private/tmp/bootbox-external-sudo/nobody"
sudo chown root:wheel \
  "$TMPDIR/bootbox-external-sudo/root-target" \
  "/private/tmp/bootbox-external-sudo/denied-target"
sudo chmod 755 \
  "$TMPDIR/bootbox-external-sudo/root-target" \
  "/private/tmp/bootbox-external-sudo" \
  "/private/tmp/bootbox-external-sudo/bootbox" \
  "/private/tmp/bootbox-external-sudo/denied-target"

# should leave the brewfile formula absent before the scenario
brew uninstall --formula --force tree >/dev/null 2>&1 || true
```

## Testing

```bash
# should let a brewfile-only plan use the real homebrew flow without bootbox sudo validation
set -o pipefail
sudo -k
BOOTBOX_EXTERNAL_SUDO=1 BOOTBOX_DEBUG=1 \
bootbox \
  --brewfile "$(pwd)/Brewfile" \
  --target "$TMPDIR/bootbox-external-sudo/root-target" \
  2>&1 | tee /dev/stderr | grep -F 'debug sudo not required: brewfile-only plan has no privileged file operations'
brew list --formula tree

# should stow a real dotpackage into a privileged target with caller-managed sudo
set -o pipefail
sudo -v
BOOTBOX_EXTERNAL_SUDO=1 \
bootbox \
  --brewfile= \
  --dotpkg "$(pwd)/dotpkgs/git" \
  --target "$TMPDIR/bootbox-external-sudo/root-target" \
  2>&1 | tee /dev/stderr | awk '/enter your admin password when prompted to continue/ { prompt=1 } END { exit prompt }'
test -L "$TMPDIR/bootbox-external-sudo/root-target/.gitconfig"
test "$(cat "$TMPDIR/bootbox-external-sudo/root-target/.gitconfig")" = "$(cat dotpkgs/git/.gitconfig)"

# should complete a real dotpackage install as a standard user without any bootbox sudo probe
set -o pipefail
sudo -u nobody /bin/sh -c 'cd /private/tmp/bootbox-external-sudo/nobody && exec /usr/bin/env "$@"' -- \
  HOME="/private/tmp/bootbox-external-sudo/nobody/home" \
  USER=nobody \
  TMPDIR="/private/tmp/bootbox-external-sudo/nobody/tmp" \
  PATH="$PATH" \
  BOOTBOX_DEBUG=1 \
  "/private/tmp/bootbox-external-sudo/bootbox" \
    --no-sudo \
    --brewfile= \
    --dotpkg "/private/tmp/bootbox-external-sudo/nobody/dotpkgs/git" \
    --target "/private/tmp/bootbox-external-sudo/nobody/home" \
  2>&1 | tee /dev/stderr | awk '
  /enter your admin password when prompted to continue/ { prompt=1 }
  /does not appear to have sudo access/ { probe=1 }
  /has sudo access/ { probe=1 }
  END { exit (prompt || probe) }
'
test -L "/private/tmp/bootbox-external-sudo/nobody/home/.gitconfig"
test "$(cat "/private/tmp/bootbox-external-sudo/nobody/home/.gitconfig")" = "$(cat dotpkgs/git/.gitconfig)"

# should reject a privileged target in no-sudo mode without probing sudo access
set +e
output="$(sudo -u nobody /bin/sh -c 'cd /private/tmp/bootbox-external-sudo/nobody && exec /usr/bin/env "$@"' -- \
  HOME="/private/tmp/bootbox-external-sudo/nobody/home" \
  USER=nobody \
  TMPDIR="/private/tmp/bootbox-external-sudo/nobody/tmp" \
  PATH="$PATH" \
  BOOTBOX_DEBUG=1 \
  "/private/tmp/bootbox-external-sudo/bootbox" \
    --no-sudo \
    --brewfile= \
    --dotpkg "/private/tmp/bootbox-external-sudo/nobody/dotpkgs/git" \
    --target "/private/tmp/bootbox-external-sudo/denied-target" 2>&1)"
command_status="$?"
set -e
printf "%s\n" "$output"
test "$command_status" -ne 0
printf "%s\n" "$output" | grep -F 'bootbox is running with --no-sudo'
if printf "%s\n" "$output" | grep -F 'does not appear to have sudo access'; then exit 1; fi
if printf "%s\n" "$output" | grep -F 'enter your admin password when prompted to continue'; then exit 1; fi
test ! -e "/private/tmp/bootbox-external-sudo/denied-target/.gitconfig"

# should reject a standard user before a standalone privileged mutation
set +e
output="$(sudo -u nobody /bin/sh -c 'cd /private/tmp/bootbox-external-sudo/nobody && exec /usr/bin/env "$@"' -- \
  HOME="/private/tmp/bootbox-external-sudo/nobody/home" \
  USER=nobody \
  TMPDIR="/private/tmp/bootbox-external-sudo/nobody/tmp" \
  PATH="$PATH" \
  "/private/tmp/bootbox-external-sudo/bootbox" \
    --brewfile= \
    --dotpkg "/private/tmp/bootbox-external-sudo/nobody/dotpkgs/git" \
    --target "/private/tmp/bootbox-external-sudo/denied-target" 2>&1)"
command_status="$?"
set -e
printf "%s\n" "$output"
test "$command_status" -ne 0
printf "%s\n" "$output" | grep -F 'nobody cannot complete the planned operation without sudo:'
test ! -e "/private/tmp/bootbox-external-sudo/denied-target/.gitconfig"

# should reject caller-managed sudo when a standard user has no credential
set +e
output="$(sudo -u nobody /bin/sh -c 'cd /private/tmp/bootbox-external-sudo/nobody && exec /usr/bin/env "$@"' -- \
  HOME="/private/tmp/bootbox-external-sudo/nobody/home" \
  USER=nobody \
  TMPDIR="/private/tmp/bootbox-external-sudo/nobody/tmp" \
  PATH="$PATH" \
  BOOTBOX_EXTERNAL_SUDO=1 \
  "/private/tmp/bootbox-external-sudo/bootbox" \
    --brewfile= \
    --dotpkg "/private/tmp/bootbox-external-sudo/nobody/dotpkgs/git" \
    --target "/private/tmp/bootbox-external-sudo/denied-target" 2>&1)"
command_status="$?"
set -e
printf "%s\n" "$output"
test "$command_status" -ne 0
printf "%s\n" "$output" | grep -F 'bootbox external sudo mode requires an active sudo credential.'
test ! -e "/private/tmp/bootbox-external-sudo/denied-target/.gitconfig"

# should reject contradictory sudo modes before mutation
set +e
output="$(BOOTBOX_EXTERNAL_SUDO=1 BOOTBOX_NO_SUDO=1 \
  bootbox --brewfile= 2>&1)"
command_status="$?"
set -e
printf "%s\n" "$output"
test "$command_status" -ne 0
printf "%s\n" "$output" | grep -F 'BOOTBOX_EXTERNAL_SUDO=1 cannot be combined with --no-sudo or BOOTBOX_NO_SUDO=1.'
```
