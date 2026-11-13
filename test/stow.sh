#!/bin/bash
# Variables and literal snippets are consumed by the sourced production functions.
# shellcheck disable=SC2034,SC2016
set -eo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
scratch="$(mktemp -d)"
scratch="$(cd -P "${scratch}" && pwd)"
trap 'rm -rf "${scratch}"' EXIT
export FIXTURE

# Source function declarations only: the bootstrap itself must never run here.
awk '/^[a-zA-Z_][a-zA-Z0-9_]*\(\) \{$/ {copy=1} copy {print} copy && /^}$/ {copy=0}' \
  "${repo}/bootbox.sh" > "${scratch}/functions.sh"

setup() {
  FIXTURE="${scratch}/$1"
  mkdir -p "${FIXTURE}/brew/Cellar/stow/2.4.1/bin" \
    "${FIXTURE}/brew/Cellar/perl/5.44.0/bin" "${FIXTURE}/brew/opt" \
    "${FIXTURE}/brew/bin" "${FIXTURE}/home" "${FIXTURE}/pkg"
  mkdir -p "${FIXTURE}/brew/"{etc,include,lib,sbin,share,var,Caskroom,Frameworks}
  mkdir "${FIXTURE}/decoy"
  printf '#!/bin/bash\necho unexpected PATH brew >&2\nexit 90\n' > "${FIXTURE}/decoy/brew"
  chmod +x "${FIXTURE}/decoy/brew"
  cp "${repo}/test/stow-command.sh" "${FIXTURE}/brew/bin/brew"
  ln -s "$(command -v perl)" "${FIXTURE}/brew/Cellar/perl/5.44.0/bin/perl"
  chmod +x "${FIXTURE}/brew/bin/brew"
  ln -s ../Cellar/stow/2.4.1 "${FIXTURE}/brew/opt/stow"
  ln -s ../Cellar/perl/5.44.0 "${FIXTURE}/brew/opt/perl"
  ln -s ../opt/stow/bin/stow "${FIXTURE}/brew/bin/stow"
  write_stow 5.38.2_1
  echo broken > "${FIXTURE}/state"
  echo original > "${FIXTURE}/home/.example"
  echo replacement > "${FIXTURE}/pkg/.example"
  : > "${FIXTURE}/commands"
}

write_stow() {
  printf '#!%s/brew/opt/perl/bin/perl\nuse lib "%s/brew/Cellar/stow/2.4.1/%s/brew/Cellar/perl/%s/lib/perl5/site_perl/5.38";\n' \
    "${FIXTURE}" "${FIXTURE}" "${FIXTURE}" "$1" > "${FIXTURE}/brew/opt/stow/bin/stow"
  cat "${repo}/test/stow-command.pl" >> "${FIXTURE}/brew/opt/stow/bin/stow"
  chmod +x "${FIXTURE}/brew/opt/stow/bin/stow"
}

run() (
  # shellcheck source=/dev/null
  source "${scratch}/functions.sh"
  export PATH="${FIXTURE}/decoy:${FIXTURE}/brew/bin:${PATH}"
  HOMEBREW_PREFIX="${FIXTURE}/brew"
  BREW="${HOMEBREW_PREFIX}/bin/brew"
  TARGET="${FIXTURE}/home"
  USER="$(id -un)"
  NO_SUDO=1
  OS=linux
  DEBUG=""
  QUIET=""
  tty_tp="" tty_ts="" tty_dim="" tty_reset="" tty_red="" tty_bold="" tty_green=""
  BOOTBOX_CORE_BREW_PACKAGES=('formula|stow|stow')
  PLANNED_ACTIONS=()
  DOTPKGS=("${FIXTURE}/pkg")
  eval "$1"
)

no_repair() {
  test ! -e "${FIXTURE}/repairs"
}

setup healthy
echo healthy > "${FIXTURE}/state"
run 'plan_core_homebrew_packages; ensure_core_stow; ensure_core_stow; test "${#PLANNED_ACTIONS[@]}" -eq 0; CHECK_CORE=1; run_check_core'
no_repair
echo 'ok: healthy bottled Stow is reused'

setup planning
run 'plan_core_homebrew_packages; plan_dotpkgs; show_planned_actions' | tee "${FIXTURE}/plan"
grep -F rebuild "${FIXTURE}/plan"
test "$(cat "${FIXTURE}/state")" = broken
if grep -F -- --simulate "${FIXTURE}/commands"; then exit 1; fi
no_repair
echo 'ok: planning queues recovery without repair or simulation'

setup check
if run 'CHECK_CORE=1; run_check_core' > "${FIXTURE}/output" 2>&1; then exit 1; fi
test ! -s "${FIXTURE}/output"
if run 'CHECK_CORE=1; DEBUG=1; run_check_core' > "${FIXTURE}/output" 2>&1; then exit 1; fi
cat "${FIXTURE}/output"
grep -F "Can't locate Stow.pm" "${FIXTURE}/output"
no_repair
echo 'ok: core checks fail quietly or expose diagnostics in debug mode'

setup unavailable-prefix
rm "${FIXTURE}/brew/bin/stow"
cp "${FIXTURE}/brew/opt/stow/bin/stow" "${FIXTURE}/brew/bin/stow"
rm "${FIXTURE}/brew/opt/stow"
if run 'CHECK_CORE=1; run_check_core' > "${FIXTURE}/output" 2>&1; then exit 1; fi
test ! -s "${FIXTURE}/output"
no_repair
echo 'ok: uncertain ownership checks also fail quietly without repair'

setup repaired
run 'plan_core_homebrew_packages; ensure_core_stow; ensure_core_stow; ensure_stow'
test "$(cat "${FIXTURE}/repairs")" = repair
echo 'ok: apply selects brew, rebuilds once without sudo, and revalidates'

setup freshly-installed
rm "${FIXTURE}/brew/bin/stow"
touch "${FIXTURE}/missing"
run 'plan_core_homebrew_packages; install_core_homebrew_packages; ensure_core_stow'
test "$(cat "${FIXTURE}/repairs")" = repair
echo 'ok: a newly installed broken bottle is repaired'

setup fresh-selection
rm "${FIXTURE}/brew/bin/stow"
touch "${FIXTURE}/missing"
run 'STOW=/usr/bin/true; plan_core_homebrew_packages; install_core_homebrew_packages; ensure_core_stow'
test "$(cat "${FIXTURE}/repairs")" = repair
echo 'ok: the installed Homebrew Stow supersedes a planning-time fallback'

for failure in fail-repair stay-broken; do
  setup "${failure}"
  touch "${FIXTURE}/${failure}"
  if run 'ensure_core_stow; echo continued' > "${FIXTURE}/output" 2>&1; then exit 1; fi
  cat "${FIXTURE}/output"
  grep -F "Can't locate Stow.pm" "${FIXTURE}/output"
  if grep -F continued "${FIXTURE}/output"; then exit 1; fi
  test "$(cat "${FIXTURE}/repairs")" = repair
done
echo 'ok: failed repair and failed post-repair validation stop after one attempt'

setup retry-limit
run 'ensure_core_stow; echo broken > "${FIXTURE}/state"; if (ensure_core_stow); then exit 1; fi'
test "$(cat "${FIXTURE}/repairs")" = repair
echo 'ok: later failures cannot trigger a second rebuild'

for failure in unrelated current-perl non-homebrew wrong-interpreter; do
  setup "${failure}"
  case "${failure}" in
    unrelated) echo unrelated > "${FIXTURE}/state" ;;
    current-perl) write_stow 5.44.0 ;;
    non-homebrew)
      cp "${FIXTURE}/brew/opt/stow/bin/stow" "${FIXTURE}/external-stow"
      rm "${FIXTURE}/brew/bin/stow"
      ln -s "${FIXTURE}/external-stow" "${FIXTURE}/brew/bin/stow"
      ;;
    wrong-interpreter)
      ln -s "$(command -v perl)" "${FIXTURE}/perl"
      sed "1s|.*|#!${FIXTURE}/perl|" "${FIXTURE}/brew/opt/stow/bin/stow" > "${FIXTURE}/patched"
      cat "${FIXTURE}/patched" > "${FIXTURE}/brew/opt/stow/bin/stow"
      ;;
  esac
  if run 'plan_core_homebrew_packages' > "${FIXTURE}/output" 2>&1; then exit 1; fi
  cat "${FIXTURE}/output"
  grep -F 'stow cannot run' "${FIXTURE}/output"
  no_repair
done
echo 'ok: unrelated failures, current paths, external Stow and other Perl are not repaired'

setup conflicts
echo healthy > "${FIXTURE}/state"
touch "${FIXTURE}/conflict"
run 'plan_core_homebrew_packages; plan_dotpkgs; test "$(cat "${TARGET}/.example")" = original; install_dotpkgs'
test -L "${FIXTURE}/home/.example"
test "$(cat "${FIXTURE}/home/.example")" = replacement
test "$(cat "${FIXTURE}/home"/.tanaab-backups/stow-*/.example)" = original
no_repair
echo 'ok: genuine conflicts retain the existing backup policy without rebuilding'

setup simulation-error
echo healthy > "${FIXTURE}/state"
touch "${FIXTURE}/simulate-error"
if run 'plan_core_homebrew_packages; plan_dotpkgs' > "${FIXTURE}/output" 2>&1; then exit 1; fi
cat "${FIXTURE}/output"
grep -F 'unexpected simulation error' "${FIXTURE}/output"
test "$(cat "${FIXTURE}/home/.example")" = original
no_repair
echo 'ok: execution errors remain distinct from conflicts and leave dotfiles alone'
