# Stow recovery example

this Linux-only scenario provisions missing Stow through the prepared `bootbox` artifact using the
runner's user-owned Homebrew prefix. it then injects an obsolete Perl module path into real Stow,
verifies a source rebuild restores dotfile setup, and repeats setup without another rebuild.

clean provisioning, synthetic fault recovery, and repeat installation have separate logs. the fault
injection exercises [#23](https://github.com/tanaabased/bootbox/issues/23); it does not reproduce the
historical bottle or establish that current bottles are broken. healthy-platform coverage remains
in [defaults](../defaults/README.md), and real conflict backups in [dotpkgs](../dotpkgs/README.md).
run only on disposable CI runners: this scenario modifies the installed Homebrew Stow script.

## Setup

```bash
# should start with missing Stow in a user-owned Linux Homebrew prefix
test "$(uname -s)" = Linux
test -O "$(brew --prefix)"
mkdir -p .tmp/home
brew uninstall --formula --force stow
```

## Testing

```bash
# should provision Stow without sudo
HOME="$(pwd)/.tmp/home" bootbox --no-sudo --brewfile= 2>&1 | tee .tmp/clean.log
bootbox --check-core

# should inject a synthetic obsolete module path into real Stow
bash inject-stale-path.sh
if stow --version > .tmp/fault.log 2>&1; then cat .tmp/fault.log; exit 1; fi
cat .tmp/fault.log
grep -F "Can't locate Stow.pm in @INC" .tmp/fault.log

# should report broken core readiness without repairing Stow
if bootbox --check-core; then exit 1; fi
if stow --version; then exit 1; fi

# should recover real Stow and apply the dotpackage
HOME="$(pwd)/.tmp/home" bootbox --no-sudo --brewfile= --dotpkg dotpkgs/shell 2>&1 | tee .tmp/recovery.log
grep -F 'rebuilding' .tmp/recovery.log | grep -F stow
test -L .tmp/home/.bootbox-stow-test
cmp .tmp/home/.bootbox-stow-test dotpkgs/shell/.bootbox-stow-test
brew info --json=v2 stow | jq -e '.formulae[0].installed | length > 0 and all(.[]; .built_as_bottle == false)'
bootbox --check-core

# should repeat setup without another source rebuild
HOME="$(pwd)/.tmp/home" bootbox --no-sudo --brewfile= --dotpkg dotpkgs/shell 2>&1 | tee .tmp/repeat.log
if grep -F rebuilding .tmp/repeat.log; then exit 1; fi
bootbox --check-core
```
