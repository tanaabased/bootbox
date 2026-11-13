# Stow failure example

this Linux-only scenario invokes prepared `bootbox` against real Stow and Perl, with controlled
dependency faults. it verifies quiet and debug readiness checks, cancellation before applying a
repair, refusal of unrelated failures and external Stow, and stopping after one failed repair.

the shared [Stow setup helpers](../stow/README.md) modify the disposable runner's Stow script and
wrap its selected Homebrew executable. normal Homebrew commands remain real. the two repair-failure
modes intercept only the rebuild command: one returns failure, and one returns success without
fixing Stow. these are controlled failure checks, not evidence of a successful real rebuild; that
belongs to [stow-recovery](../stow-recovery/README.md). real conflict backups remain in [dotpkgs](../dotpkgs/README.md).
run only on disposable CI runners.

## Setup

```bash
# should prepare real core dependencies and an untouched home file
mkdir -p .tmp/home
HOME="$(pwd)/.tmp/home" bootbox --no-sudo --brewfile=
cp ../stow/dotpkgs/shell/.bootbox-stow-test .tmp/home/.bootbox-stow-test
readlink "$(brew --prefix)/bin/stow" > .tmp/stow-link
bash ../stow/prepare-brew-wrapper.sh
```

## Testing

```bash
# should keep broken readiness checks read-only with useful debug diagnostics
bash ../stow/inject-stale-path.sh
if bootbox --check-core > .tmp/quiet.log 2>&1; then cat .tmp/quiet.log; exit 1; fi
test ! -s .tmp/quiet.log
if bootbox --check-core --debug > .tmp/debug.log 2>&1; then cat .tmp/debug.log; exit 1; fi
cat .tmp/debug.log
grep -F "Can't locate Stow.pm in @INC" .tmp/debug.log
cmp .tmp/stow-broken "$(brew --prefix stow)/bin/stow"
test ! -e "$(brew --prefix)/.bootbox-stow-test/repairs"

# should show the repair plan and abort before changing packages or dotfiles
bootbox="$(command -v bootbox)"
set +e
printf x | timeout 20s script -q -e -c "env -u CI -u NONINTERACTIVE INTERACTIVE=1 HOME='$(pwd)/.tmp/home' '$bootbox' --no-sudo --brewfile= --dotpkg '$(pwd)/../stow/dotpkgs/shell'" /dev/null > .tmp/plan.log 2>&1
command_status="$?"
set -e
cat .tmp/plan.log
test "$command_status" -eq 1
grep -F rebuild .tmp/plan.log
grep -F 'to continue or any other key to abort' .tmp/plan.log
test ! -e "$(brew --prefix)/.bootbox-stow-test/repairs"
cmp .tmp/stow-broken "$(brew --prefix stow)/bin/stow"
test ! -L .tmp/home/.bootbox-stow-test

# should refuse unrelated execution failures without attempting a rebuild
for fault in unrelated current-perl other-perl; do
  bash ../stow/inject-stale-path.sh restore
  bash ../stow/inject-stale-path.sh "$fault"
  if HOME="$(pwd)/.tmp/home" bootbox --no-sudo --brewfile= --dotpkg ../stow/dotpkgs/shell > .tmp/refusal.log 2>&1; then cat .tmp/refusal.log; exit 1; fi
  cat .tmp/refusal.log
  grep -F 'stow cannot run' .tmp/refusal.log
  test ! -e "$(brew --prefix)/.bootbox-stow-test/repairs"
  test ! -L .tmp/home/.bootbox-stow-test
done

# should refuse a missing-module failure from Stow outside the Homebrew keg
bash ../stow/inject-stale-path.sh restore
bash ../stow/inject-stale-path.sh
cp "$(brew --prefix stow)/bin/stow" .tmp/external-stow
ln -sfn "$(pwd)/.tmp/external-stow" "$(brew --prefix)/bin/stow"
if HOME="$(pwd)/.tmp/home" bootbox --no-sudo --brewfile= --dotpkg ../stow/dotpkgs/shell > .tmp/external.log 2>&1; then cat .tmp/external.log; exit 1; fi
cat .tmp/external.log
grep -F "Can't locate Stow.pm in @INC" .tmp/external.log
test ! -e "$(brew --prefix)/.bootbox-stow-test/repairs"
ln -sfn "$(cat .tmp/stow-link)" "$(brew --prefix)/bin/stow"

# should stop after one failed rebuild through the selected Homebrew executable
bash ../stow/inject-stale-path.sh restore
bash ../stow/inject-stale-path.sh
control="$(brew --prefix)/.bootbox-stow-test"
echo fail-repair > "$control/mode"
if HOME="$(pwd)/.tmp/home" bootbox --no-sudo --brewfile= --dotpkg ../stow/dotpkgs/shell > .tmp/repair-failed.log 2>&1; then cat .tmp/repair-failed.log; exit 1; fi
cat .tmp/repair-failed.log
grep -F 'controlled Homebrew rebuild failure' .tmp/repair-failed.log
grep -Fx "$(brew --prefix)/bin/brew reinstall --build-from-source stow" "$control/repairs"
test "$(wc -l < "$control/repairs")" -eq 1
test ! -L .tmp/home/.bootbox-stow-test
test ! -d .tmp/home/.tanaab-backups
cmp .tmp/home/.bootbox-stow-test ../stow/dotpkgs/shell/.bootbox-stow-test

# should revalidate a reported rebuild success and stop if Stow is still broken
bash ../stow/inject-stale-path.sh restore
bash ../stow/inject-stale-path.sh
control="$(brew --prefix)/.bootbox-stow-test"
: > "$control/repairs"
echo leave-broken > "$control/mode"
if HOME="$(pwd)/.tmp/home" bootbox --no-sudo --brewfile= --dotpkg ../stow/dotpkgs/shell > .tmp/still-broken.log 2>&1; then cat .tmp/still-broken.log; exit 1; fi
cat .tmp/still-broken.log
grep -F 'controlled Homebrew success without repairing Stow' .tmp/still-broken.log
grep -F "Can't locate Stow.pm in @INC" .tmp/still-broken.log
test "$(wc -l < "$control/repairs")" -eq 1
test ! -L .tmp/home/.bootbox-stow-test
test ! -d .tmp/home/.tanaab-backups
cmp .tmp/home/.bootbox-stow-test ../stow/dotpkgs/shell/.bootbox-stow-test
```
