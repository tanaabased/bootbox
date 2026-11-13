#!/bin/bash
set -euo pipefail

printf '%s\n' "$*" >> "${FIXTURE}/commands"
case "$(basename "$0")" in
  brew)
    case "$*" in
      --version) echo 'Homebrew fixture' ;;
      --prefix) echo "${FIXTURE}/brew" ;;
      '--prefix stow') echo "${FIXTURE}/brew/opt/stow" ;;
      '--prefix perl') echo "${FIXTURE}/brew/opt/perl" ;;
      --repository) echo "${FIXTURE}/brew" ;;
      --cellar) echo "${FIXTURE}/brew/Cellar" ;;
      '--cellar perl') echo "${FIXTURE}/brew/Cellar/perl" ;;
      '--cellar stow') echo "${FIXTURE}/brew/Cellar/stow" ;;
      shellenv)
        # shellcheck disable=SC2016
        printf 'export PATH="%s/brew/bin:$PATH"\n' "${FIXTURE}"
        ;;
      'list --formula stow') test ! -e "${FIXTURE}/missing" ;;
      list*) exit 0 ;;
      'install stow')
        rm "${FIXTURE}/missing"
        ln -s ../opt/stow/bin/stow "${FIXTURE}/brew/bin/stow"
        ;;
      'reinstall --build-from-source stow')
        echo repair >> "${FIXTURE}/repairs"
        if [[ -e "${FIXTURE}/fail-repair" ]]; then
          echo 'compiler fixture failure' >&2
          exit 1
        fi
        if [[ ! -e "${FIXTURE}/stay-broken" ]]; then
          echo healthy > "${FIXTURE}/state"
        fi
        ;;
      *) echo "unexpected brew command: $*" >&2; exit 90 ;;
    esac
    ;;
  *) echo 'unexpected fixture executable' >&2; exit 90 ;;
esac
