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
bootbox --brewfile=

# should install Homebrew into the platform canonical prefix
command -v brew
brew --prefix | grep -E '^(/opt/homebrew|/home/linuxbrew/\.linuxbrew)$'

# should satisfy the built-in core readiness check
bootbox --check-core
```
