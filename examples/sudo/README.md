# Sudo Example

This example exercises `bootbox` sudo boundaries with real Homebrew, Stow, users, permissions, and
sudo state. It verifies that existing Homebrew and current-user configuration never trigger Bootbox
sudo validation, while inaccessible Homebrew and home directories fail without elevation.

## Setup

```bash
# should prepare the real bootbox core toolchain
bootbox --brewfile=
bootbox --check-core

# should prepare writable and inaccessible home fixtures
rm -rf "$TMPDIR/bootbox-sudo"
sudo rm -rf /tmp/bootbox-sudo
mkdir -p "$TMPDIR/bootbox-sudo/home"
sudo mkdir -p \
  "$TMPDIR/bootbox-sudo/root-home" \
  /tmp/bootbox-sudo/nobody/home \
  /tmp/bootbox-sudo/nobody/tmp
sudo cp "$(command -v bootbox)" /tmp/bootbox-sudo/bootbox
sudo chown -R nobody /tmp/bootbox-sudo/nobody
sudo chmod 755 \
  "$TMPDIR/bootbox-sudo/root-home" \
  /tmp/bootbox-sudo \
  /tmp/bootbox-sudo/bootbox

# should leave the brewfile formula absent before the scenario
brew uninstall --formula --force tree >/dev/null 2>&1 || true
```

## Testing

```bash
# should let a brewfile-only plan use existing Homebrew without bootbox sudo validation
set -o pipefail
sudo -k
HOME="$TMPDIR/bootbox-sudo/home" BOOTBOX_DEBUG=1 \
bootbox --brewfile "$(pwd)/Brewfile" \
  2>&1 | awk '
  { print }
  /debug sudo not required: brewfile-only plan has no privileged file operations/ { found=1 }
  END { exit !found }
'
brew list --formula tree

# should stow dotpackages into HOME without probing or prompting for sudo
set -o pipefail
sudo -k
HOME="$TMPDIR/bootbox-sudo/home" BOOTBOX_DEBUG=1 \
bootbox --brewfile= --dotpkg "$(pwd)/dotpkgs/git" \
  2>&1 | awk '
  { print }
  /enter your admin password when prompted to continue/ { prompt=1 }
  /does not appear to have sudo access/ { probe=1 }
  /has sudo access/ { probe=1 }
  END { exit (prompt || probe) }
'
test -L "$TMPDIR/bootbox-sudo/home/.gitconfig"
test "$(cat "$TMPDIR/bootbox-sudo/home/.gitconfig")" = "$(cat dotpkgs/git/.gitconfig)"

# should reject a home directory not owned by the invoking user without probing sudo
set +e
output="$(HOME="$TMPDIR/bootbox-sudo/root-home" BOOTBOX_DEBUG=1 \
  bootbox --brewfile= --dotpkg "$(pwd)/dotpkgs/git" 2>&1)"
command_status="$?"
set -e
printf "%s\n" "$output"
test "$command_status" -ne 0
printf "%s\n" "$output" | grep -F 'current user home directory is not owned by'
if printf "%s\n" "$output" | grep -F 'has sudo access'; then exit 1; fi
if printf "%s\n" "$output" | grep -F 'enter your admin password when prompted to continue'; then exit 1; fi

# should reject Homebrew that the invoking user cannot manage without probing sudo
set +e
output="$(sudo -u nobody /bin/sh -c 'cd /tmp/bootbox-sudo/nobody && exec /usr/bin/env "$@"' -- \
  HOME=/tmp/bootbox-sudo/nobody/home \
  USER=nobody \
  CI="$CI" \
  TMPDIR=/tmp/bootbox-sudo/nobody/tmp \
  PATH="$PATH" \
  BOOTBOX_DEBUG=1 \
  /tmp/bootbox-sudo/bootbox --no-sudo --brewfile= 2>&1)"
command_status="$?"
set -e
printf "%s\n" "$output"
test "$command_status" -ne 0
printf "%s\n" "$output" | grep -F 'cannot be managed by nobody'
printf "%s\n" "$output" | grep -F 'bootbox will not use sudo to repair an existing Homebrew installation.'
if printf "%s\n" "$output" | grep -F 'has sudo access'; then exit 1; fi
if printf "%s\n" "$output" | grep -F 'enter your admin password when prompted to continue'; then exit 1; fi
```
