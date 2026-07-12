# Homebrew Example

This example moves the GitHub runner's preinstalled Homebrew prefix aside, verifies that Homebrew is
unavailable, and exercises a complete `bootbox` installation into the platform's canonical prefix.

## Setup

```bash
# should move the runner Homebrew installation out of the canonical prefix
brew_prefix="$(brew --prefix)"
printf "%s\n" "$brew_prefix" | grep -E '^(/opt/homebrew|/home/linuxbrew/\.linuxbrew)$'
sudo mv "$brew_prefix" "$brew_prefix-runner"
hash -r
test ! -x "$brew_prefix/bin/brew"
! command -v brew
```

## Testing

```bash
# should install Homebrew and the complete bootbox core
set -o pipefail
mkdir -p "$TMPDIR/bootbox-homebrew-home"
HOME="$TMPDIR/bootbox-homebrew-home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
  "$(command -v bootbox)" --brewfile= 2>&1 | tee "$TMPDIR/bootbox-homebrew-install.log"
grep -F 'add Homebrew to future shells' "$TMPDIR/bootbox-homebrew-install.log"

# should install Homebrew into the platform canonical prefix
command -v brew
brew --prefix | grep -E '^(/opt/homebrew|/home/linuxbrew/\.linuxbrew)$'

# should satisfy the built-in core readiness check
bootbox --check-core

# should skip Snap cURL when a compatible alternative is available on Linux
if [[ "$(uname)" == "Linux" ]]; then
  sudo mkdir -p /snap/bin
  sudo ln -sf "$(command -v curl)" /snap/bin/curl
  PATH="/snap/bin:$PATH" BOOTBOX_DEBUG=1 bootbox --brewfile= 2>&1 | awk '
    { print }
    /debug using the cURL at \/snap\/bin\/curl/ { snap=1 }
    /debug using the cURL at / { found=1 }
    END { exit (!found || snap) }
  '
fi
```
