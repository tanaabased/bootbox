# Defaults Example

This example exercises the default `bootbox` bootstrap path. It starts with an incomplete core
toolchain and an unsatisfied implicit `./Brewfile`, then verifies that one option-free run satisfies
the complete default state.

## Setup

```bash
# should prepare an incomplete default state
rm -rf .tmp && mkdir -p .tmp
brew uninstall --formula --force stow watch
```

## Testing

```bash
# should fail the built-in core readiness check before setup
! bootbox --check-core

# should run the default bootstrap successfully
bootbox > .tmp/setup.log 2>&1

# should report that the built-in core readiness check passes after setup
bootbox --check-core

# should make Homebrew available
command -v brew >/dev/null || test -x /opt/homebrew/bin/brew || test -x /usr/local/bin/brew

# should install the complete core formula set
brew list --formula git
brew list --formula curl
brew list --formula zsh
brew list --formula jq
brew list --formula stow

# should install the core 1password cli cask
brew list --cask 1password-cli@beta

# should expose 1password environment support
op run --help | grep -F -- '--environment'

# should discover the default local Brewfile
grep -F "$(pwd)/Brewfile" .tmp/setup.log

# should satisfy the default local Brewfile
brew list --formula watch
```
