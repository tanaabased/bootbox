# Bootbox Minimal Example

This example is the smallest markdown-first bootstrap test for `bootbox`. It forces Bootbox's
core readiness check into a failing state when Homebrew is already present, then runs the default
setup path against an example-local target directory and verifies that the core check and expected
toolchain are satisfied afterwards.

## Setup

```bash
# should reset the example scratch directory
rm -rf .tmp && mkdir -p .tmp/home

# should remove a core formula first when Homebrew is already present
brew uninstall --formula --force stow
```

## Testing

```bash
# should fail the built-in core readiness check before setup
! bootbox --check-core

# should repair the built-in core readiness check with the default setup path
CI=1 NONINTERACTIVE=1 bootbox --target "$(pwd)/.tmp/home" > .tmp/setup.log 2>&1

# should report that the built-in core readiness check passes after setup
bootbox --check-core

# should create the example-local target directory
test -d .tmp/home

# should make Homebrew available
command -v brew >/dev/null || test -x /opt/homebrew/bin/brew || test -x /usr/local/bin/brew

# should make git available
command -v git >/dev/null

# should make jq available
command -v jq >/dev/null || test -x /opt/homebrew/bin/jq || test -x /usr/local/bin/jq

# should make stow available
command -v stow >/dev/null || test -x /opt/homebrew/bin/stow || test -x /usr/local/bin/stow

# should make 1password cli available
command -v op >/dev/null || test -x /opt/homebrew/bin/op || test -x /usr/local/bin/op
```

## Destroy tests

```bash
# should remove the example scratch directory
rm -rf .tmp
```
