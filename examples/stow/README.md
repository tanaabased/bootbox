# Stow example

this macOS and Linux scenario provisions missing Stow through the prepared `bootbox` artifact,
applies a dotpackage, and repeats setup without rebuilding healthy Stow.

synthetic Homebrew Perl recovery belongs to the Linux-only [stow-recovery](../stow-recovery/README.md)
scenario, and controlled failures to [stow-failures](../stow-failures/README.md).
run only on disposable CI runners.

## Setup

```bash
# should start with missing Stow in a user-owned Homebrew prefix
test -O "$(brew --prefix)"
mkdir -p .tmp/home
brew uninstall --formula --force stow
```

## Testing

```bash
# should provision Stow and apply the dotpackage without sudo
HOME="$(pwd)/.tmp/home" bootbox --no-sudo --brewfile= --dotpkg dotpkgs/shell 2>&1 | tee .tmp/clean.log
test -L .tmp/home/.bootbox-stow-test
cmp .tmp/home/.bootbox-stow-test dotpkgs/shell/.bootbox-stow-test
bootbox --check-core

# should repeat setup without rebuilding healthy Stow
HOME="$(pwd)/.tmp/home" bootbox --no-sudo --brewfile= --dotpkg dotpkgs/shell 2>&1 | tee .tmp/repeat.log
if grep -F rebuilding .tmp/repeat.log; then exit 1; fi
test -L .tmp/home/.bootbox-stow-test
cmp .tmp/home/.bootbox-stow-test dotpkgs/shell/.bootbox-stow-test
bootbox --check-core
```
