# Bootbox Minimal Example

This example is the smallest markdown-first bootstrap test for `bootbox.sh`. It runs the default
setup path against an example-local target directory and verifies that the core toolchain Bootbox
expects is available afterwards.

## Setup

```bash
# should reset the example scratch directory
rm -rf .tmp && mkdir -p .tmp/home

# should run bootbox with its default setup path
CI=1 NONINTERACTIVE=1 bootbox.sh --target "$(pwd)/.tmp/home" > .tmp/setup.log 2>&1
```

## Testing

```bash
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
