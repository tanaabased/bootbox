#!/bin/bash
set -euo pipefail
# bootstrap a macOS or Linux machine using homebrew, brewfiles, dotfiles, and identity data.
#
# examples:
#
#   $ ./bootbox.sh
#   $ ./bootbox.sh --brewfile Brewfile.work
#   $ DEBUG=1 ./bootbox.sh --yes
#
# option precedence: cli options override environment variables, which override defaults.
#
# run `./bootbox.sh --help` for more advanced usage.
#
# note: stow --dotfiles is not currently implemented.

# Any code that has been modified by the original falls under
# Copyright (c) 2026, Tanaab Maneuvering Systems LLC
#
# All rights reserved.
# See license in the repo: https://github.com/tanaabased/bootbox/blob/main/LICENSE
#
# We don't need return codes for "$(command)", only stdout is needed.
# Allow `[[ -n "$(command)" ]]`, `func "$(command)"`, pipes, etc.
# shellcheck disable=SC2312

# CONFIG
MACOS_OLDEST_SUPPORTED="26.0"
REQUIRED_CURL_VERSION="7.41.0"
REQUIRED_GIT_VERSION="2.7.0"
REQUIRED_GLIBC_VERSION="2.13"
REQUIRED_SUDO_VERSION="1.9.12"
INHERITED_PATH="${PATH-}"

abort() {
  printf "error: %s\n" "$@" >&2
  exit 1
}

# Fail fast with a concise message when not using bash
# Single brackets are needed here for POSIX compatibility
# shellcheck disable=SC2292
if [ -z "${BASH_VERSION:-}" ]; then
  abort "bash is required to interpret this script."
fi

# Check if both `INTERACTIVE` and `NONINTERACTIVE` are set
# Always use single-quoted strings with `exp` expressions
# shellcheck disable=SC2016
if [[ -n "${INTERACTIVE-}" && -n "${NONINTERACTIVE-}" ]]; then
  abort 'both $INTERACTIVE and $NONINTERACTIVE are set. please unset at least one variable and try again.'
fi

# Check if script is run with force-interactive mode in CI
if [[ -n "${CI-}" && -n "${INTERACTIVE-}" ]]; then
  abort "cannot run force-interactive mode in CI."
fi

# Check if script is run in POSIX mode
if [[ -n "${POSIXLY_CORRECT+1}" ]]; then
  abort 'bash must not run in POSIX mode. please unset POSIXLY_CORRECT and try again.'
fi

if [[ -t 1 ]]; then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_mkdim() { tty_escape "2;$1"; }
# shellcheck disable=SC2034  # Keep the shared palette available even when a given change doesn't use blue.
tty_blue="$(tty_escape 34)"
tty_bold="$(tty_mkbold 39)"
tty_dim="$(tty_mkdim 39)"
tty_green="$(tty_escape 32)"
tty_magenta="$(tty_escape 35)"
tty_red="$(tty_mkbold 31)"
tty_reset="$(tty_escape 0)"
tty_underline="$(tty_escape "4;39")"
tty_yellow="$(tty_escape 33)"

# Tanaab based colors
tty_tp="$(tty_escape '38;2;0;200;138')"    # #00c88a
tty_ts="$(tty_escape '38;2;219;39;119')"   # #db2777

# Keep a single top-level assignment so release automation can stamp the entrypoint in place.
SCRIPT_VERSION="${SCRIPT_VERSION:-$(git describe --tags --always --abbrev=1 2>/dev/null || printf '%s' '0.0.0-unreleased')}"
SCRIPT_NAME_SOURCE="${BASH_SOURCE[0]:-${0}}"
SCRIPT_NAME="${SCRIPT_NAME_SOURCE##*/}"

case "${SCRIPT_NAME}" in
  '' | stdin | bash | -bash | sh | -sh)
    SCRIPT_NAME="bootbox.sh"
    ;;
esac

mask_secret_for_display() {
  local value="$1"
  local length="${#value}"
  local prefix_length="4"
  local suffix_length="4"
  local suffix_start

  if [[ -z "${value}" ]]; then
    printf "none"
    return 0
  fi

  if [[ "${length}" -le 4 ]]; then
    printf "****"
    return 0
  fi

  if [[ "${length}" -le 8 ]]; then
    prefix_length="2"
    suffix_length="2"
  fi

  suffix_start=$((length - suffix_length))
  printf "%s...%s" "${value:0:${prefix_length}}" "${value:${suffix_start}:${suffix_length}}"
}

op_token_for_display() {
  if [[ -n "${OP_TOKEN:-}" ]]; then
    mask_secret_for_display "${OP_TOKEN}"
  else
    printf "none"
  fi
}

value_enabled() {
  case "${1:-}" in
    '' | 0 | false | FALSE | False | no | NO | No | off | OFF | Off)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

env_value() {
  local preferred_name="$1"
  local legacy_name="$2"
  local fallback="${3-}"
  local preferred_value="${!preferred_name-}"
  local legacy_value="${!legacy_name-}"

  if [[ -n "${preferred_value}" ]]; then
    printf "%s" "${preferred_value}"
  elif [[ -n "${legacy_value}" ]]; then
    printf "%s" "${legacy_value}"
  else
    printf "%s" "${fallback}"
  fi
}

env_list_value() {
  local preferred_name="$1"
  local preferred_plural_name="$2"
  local legacy_name="$3"
  local legacy_plural_name="$4"
  local primary
  local secondary

  primary="${!preferred_name-}"
  secondary="${!preferred_plural_name-}"
  if [[ -n "${primary}" || -n "${secondary}" ]]; then
    printf "%s%s%s" "${primary}" "${primary:+${secondary:+,}}" "${secondary}"
    return 0
  fi

  primary="${!legacy_name-}"
  secondary="${!legacy_plural_name-}"
  printf "%s%s%s" "${primary}" "${primary:+${secondary:+,}}" "${secondary}"
}

# Set cheap defaults needed by usage/arg parsing first so --help/--version stay fast.
#
# RUNNER_DEBUG is used here so we can get good debug output when toggled in GitHub Actions
# see https://github.blog/changelog/2022-05-24-github-actions-re-run-jobs-with-debug-logging/
DEBUG="$(env_value BOOTBOX_DEBUG TANAAB_DEBUG "${DEBUG:-${RUNNER_DEBUG:-}}")"
FORCE="$(env_value BOOTBOX_FORCE TANAAB_FORCE)"
QUIET="$(env_value BOOTBOX_QUIET TANAAB_QUIET)"
NO_SUDO="${BOOTBOX_NO_SUDO:-}"
EXTERNAL_SUDO="${BOOTBOX_EXTERNAL_SUDO:-}"
CHECK_CORE=""
TARGET="${HOME:-}"
BREWFILES_CSV="$(env_list_value BOOTBOX_BREWFILE BOOTBOX_BREWFILES TANAAB_BREWFILE TANAAB_BREWFILES)"
DOTPKGS_CSV="$(env_list_value BOOTBOX_DOTPKG BOOTBOX_DOTPKGS TANAAB_DOTPKG TANAAB_DOTPKGS)"
OP_TOKEN="$(env_value BOOTBOX_OP_TOKEN TANAAB_OP_TOKEN "${OP_SERVICE_ACCOUNT_TOKEN:-}")"
SSH_KEYS_CSV="$(env_list_value BOOTBOX_SSH_KEY BOOTBOX_SSH_KEYS TANAAB_SSH_KEY TANAAB_SSH_KEYS)"

# collect them all togethers with fallback if still empty
if [[ -z "${BREWFILES_CSV}" ]] && [[ -f "./Brewfile" ]]; then
  BREWFILES_CSV="./Brewfile"
fi

trim_whitespace() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"

  printf "%s" "${value}"
}

append_array_value() {
  local array_name="$1"
  local value
  local quoted

  value="$(trim_whitespace "$2")"
  if [[ -n "${value}" ]]; then
    printf -v quoted '%q' "${value}"
    eval "${array_name}+=(${quoted})"
  fi
}

append_csv_to_array() {
  local array_name="$1"
  local old_ifs="${IFS}"
  local entry
  local -a values=()

  if [[ -z "${2}" ]]; then
    return 0
  fi

  IFS=','
  read -r -a values <<< "${2}"
  IFS="${old_ifs}"

  if [[ "${#values[@]}" -eq 0 ]]; then
    return 0
  fi

  for entry in "${values[@]}"; do
    append_array_value "${array_name}" "${entry}"
  done
}

array_join() {
  local delimiter="$1"
  local array_name="$2"
  local item
  local first="1"
  local value_count="0"
  local -a values=()

  eval "value_count=\${#${array_name}[@]}"
  if [[ "${value_count}" -eq 0 ]]; then
    return 0
  fi

  eval "values=(\"\${${array_name}[@]}\")"

  for item in "${values[@]}"; do
    if [[ "${first}" == "1" ]]; then
      printf "%s" "${item}"
      first="0"
    else
      printf "%s%s" "${delimiter}" "${item}"
    fi
  done
}

array_contains() {
  local needle="$1"
  local array_name="$2"
  local item
  local value_count="0"
  local -a values=()

  eval "value_count=\${#${array_name}[@]}"
  if [[ "${value_count}" -eq 0 ]]; then
    return 1
  fi

  eval "values=(\"\${${array_name}[@]}\")"

  for item in "${values[@]}"; do
    if [[ "${item}" == "${needle}" ]]; then
      return 0
    fi
  done

  return 1
}

append_unique_array_value() {
  local array_name="$1"
  local value

  value="$(trim_whitespace "$2")"
  if [[ -z "${value}" ]]; then
    return 0
  fi

  if array_contains "${value}" "${array_name}"; then
    return 0
  fi

  append_array_value "${array_name}" "${value}"
}

# shellcheck disable=SC2034
declare -a BREWFILES=()
declare -a DOTPKGS=()
declare -a SSH_KEYS=()
append_csv_to_array BREWFILES "${BREWFILES_CSV}"
append_csv_to_array DOTPKGS "${DOTPKGS_CSV}"
append_csv_to_array SSH_KEYS "${SSH_KEYS_CSV}"
BREWFILES_CSV="$(array_join "," BREWFILES)"
DOTPKGS_CSV="$(array_join "," DOTPKGS)"
SSH_KEYS_CSV="$(array_join "," SSH_KEYS)"

for arg in "$@"; do
  case "${arg}" in
    --brewfile | --brewfile=* | --brewfiles | --brewfiles=*)
      # shellcheck disable=SC2034
      BREWFILES=()
      ;;
    --dotpkg | --dotpkg=* | --dotpkgs | --dotpkgs=*)
      # shellcheck disable=SC2034
      DOTPKGS=()
      ;;
    --ssh-key | --ssh-key=* | --ssh-keys | --ssh-keys=*)
      # shellcheck disable=SC2034
      SSH_KEYS=()
      ;;
  esac
done

usage() {
  local brewfiles_display
  local debug_display="off"
  local dotpkgs_display
  local force_display="off"
  local no_sudo_display="off"
  local quiet_display="off"
  local ssh_keys_display

  brewfiles_display="$(array_join "," BREWFILES)"
  brewfiles_display="${brewfiles_display:-none}"
  dotpkgs_display="$(array_join "," DOTPKGS)"
  dotpkgs_display="${dotpkgs_display:-none}"
  ssh_keys_display="$(array_join "," SSH_KEYS)"
  ssh_keys_display="${ssh_keys_display:-none}"

  if value_enabled "${DEBUG:-}"; then
    debug_display="on"
  fi

  if value_enabled "${FORCE:-}"; then
    force_display="on"
  fi

  if value_enabled "${QUIET:-}"; then
    quiet_display="on"
  fi

  if value_enabled "${NO_SUDO:-}"; then
    no_sudo_display="on"
  fi

  cat <<EOS
Usage: ${tty_dim}[NONINTERACTIVE=1] [CI=1] [BOOTBOX_*...]${tty_reset} ${tty_bold}${SCRIPT_NAME}${tty_reset} ${tty_dim}[options]${tty_reset}

${tty_tp}Options:${tty_reset}
  --brewfile       installs brewfiles from local paths or URLs ${tty_dim}[default: ${brewfiles_display}]${tty_reset}
  --dotpkg         stows dot packages into the current user's home ${tty_dim}[default: ${dotpkgs_display}]${tty_reset}
  --ssh-key        installs 1password ssh keys into the current user's .ssh as vault/item[:filename] ${tty_dim}[default: ${ssh_keys_display}]${tty_reset}
  --op-token       auths with 1password service account token ${tty_dim}[default: $(op_token_for_display)]${tty_reset}
  --version        shows version of this script
  --debug          shows debug messages ${tty_dim}[default: ${debug_display}]${tty_reset}
  --quiet          suppresses bootbox status output ${tty_dim}[default: ${quiet_display}]${tty_reset}
  --no-sudo        disables sudo checks, prompts, and elevation ${tty_dim}[default: ${no_sudo_display}]${tty_reset}
  --force          forces supported overwrite operations ${tty_dim}[default: ${force_display}]${tty_reset}
  -h, --help       displays this help message
  -y, --yes        runs with all defaults and no prompts, sets NONINTERACTIVE=1

${tty_tp}Environment Variables:${tty_reset}
  BOOTBOX_BREWFILE same as --brewfile
  BOOTBOX_DOTPKG   same as --dotpkg
  BOOTBOX_SSH_KEY  same as --ssh-key
  BOOTBOX_OP_TOKEN same as --op-token; falls back to OP_SERVICE_ACCOUNT_TOKEN
  BOOTBOX_FORCE    same as --force
  BOOTBOX_QUIET    same as --quiet
  BOOTBOX_NO_SUDO  same as --no-sudo
  BOOTBOX_DEBUG    same as --debug
  NONINTERACTIVE   same as --yes
  CI               runs in CI mode and disables prompts
EOS
  if [[ "${1:-0}" != "noexit" ]]; then
    exit "${1:-0}"
  fi
}

show_version() {
  printf "%s\n" "${SCRIPT_VERSION}"
  exit 0
}

abort_option_usage() {
  usage "noexit"
  abort "$1"
}

require_next_option_value() {
  local option="$1"
  local argc="$2"

  if [[ "${argc}" -lt 2 ]]; then
    abort_option_usage "option ${tty_bold}${option}${tty_reset} requires a value."
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --brewfile)
      require_next_option_value "--brewfile" "$#"
      append_array_value BREWFILES "$2"
      shift 2
      ;;
    --brewfile=*)
      append_array_value BREWFILES "${1#*=}"
      shift
      ;;
    --brewfiles)
      require_next_option_value "--brewfiles" "$#"
      append_csv_to_array BREWFILES "$2"
      shift 2
      ;;
    --brewfiles=*)
      append_csv_to_array BREWFILES "${1#*=}"
      shift
      ;;
    --dotpkg)
      require_next_option_value "--dotpkg" "$#"
      append_array_value DOTPKGS "$2"
      shift 2
      ;;
    --dotpkg=*)
      append_array_value DOTPKGS "${1#*=}"
      shift
      ;;
    --dotpkgs)
      require_next_option_value "--dotpkgs" "$#"
      append_csv_to_array DOTPKGS "$2"
      shift 2
      ;;
    --dotpkgs=*)
      append_csv_to_array DOTPKGS "${1#*=}"
      shift
      ;;
    --ssh-key)
      require_next_option_value "--ssh-key" "$#"
      append_array_value SSH_KEYS "$2"
      shift 2
      ;;
    --ssh-key=*)
      append_array_value SSH_KEYS "${1#*=}"
      shift
      ;;
    --ssh-keys)
      require_next_option_value "--ssh-keys" "$#"
      append_csv_to_array SSH_KEYS "$2"
      shift 2
      ;;
    --ssh-keys=*)
      append_csv_to_array SSH_KEYS "${1#*=}"
      shift
      ;;
    --op-token)
      require_next_option_value "--op-token" "$#"
      OP_TOKEN="$2"
      shift 2
      ;;
    --op-token=*)
      OP_TOKEN="${1#*=}"
      shift
      ;;

    --debug)
      DEBUG=1
      shift
      ;;
    --quiet)
      QUIET=1
      shift
      ;;
    --no-sudo)
      NO_SUDO=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --check-core)
      CHECK_CORE="1"
      shift
      ;;

    -h | --help)
      usage
      ;;
    --version)
      show_version
      ;;
    -y | --yes)
      NONINTERACTIVE="1"
      shift
      ;;
    *)
      usage "noexit"
      abort "unrecognized option ${tty_bold}$1${tty_reset}; see usage above."
      ;;
  esac
done

brewfile_is_url() {
  [[ "$1" =~ ^[[:alpha:]][[:alnum:].+-]*:// ]]
}

normalize_local_path() {
  local path="$1"
  local path_dir="."
  local path_name="$path"
  local base_dir
  local resolved_dir

  if [[ "${path}" == */* ]]; then
    path_dir="${path%/*}"
    path_name="${path##*/}"
  fi

  if [[ "${path}" == /* ]]; then
    base_dir="${path_dir}"
  else
    base_dir="${PWD}/${path_dir}"
  fi

  if [[ -d "${base_dir}" ]]; then
    resolved_dir="$(cd "${base_dir}" 2>/dev/null && pwd -P)"
  else
    resolved_dir=""
  fi

  if [[ -n "${resolved_dir}" ]]; then
    printf "%s/%s" "${resolved_dir}" "${path_name}"
  elif [[ "${path}" == /* ]]; then
    printf "%s" "${path}"
  else
    printf "%s/%s" "${PWD}" "${path}"
  fi
}

normalize_brewfile() {
  local brewfile="$1"

  if brewfile_is_url "${brewfile}"; then
    printf "%s" "${brewfile}"
  else
    normalize_local_path "${brewfile}"
  fi
}

normalize_brewfiles() {
  local brewfile
  local normalized
  local -a normalized_brewfiles=()

  if [[ "${#BREWFILES[@]}" -eq 0 ]]; then
    return 0
  fi

  for brewfile in "${BREWFILES[@]}"; do
    normalized="$(normalize_brewfile "${brewfile}")"
    normalized_brewfiles+=("${normalized}")
  done

  BREWFILES=("${normalized_brewfiles[@]}")
}

validate_brewfiles() {
  local brewfile

  if [[ "${#BREWFILES[@]}" -eq 0 ]]; then
    return 0
  fi

  for brewfile in "${BREWFILES[@]}"; do
    if brewfile_is_url "${brewfile}"; then
      continue
    fi

    if [[ ! -f "${brewfile}" ]]; then
      abort "brewfile not found: ${brewfile}"
    fi
  done
}

normalize_dotpkg() {
  local dotpkg="$1"

  if [[ -d "${dotpkg}" ]]; then
    (
      cd "${dotpkg}" 2>/dev/null || exit 1
      pwd -P
    )
  elif [[ "${dotpkg}" == /* ]]; then
    printf "%s" "${dotpkg}"
  else
    printf "%s/%s" "${PWD}" "${dotpkg}"
  fi
}

normalize_dotpkgs() {
  local dotpkg
  local normalized
  local -a normalized_dotpkgs=()

  if [[ "${#DOTPKGS[@]}" -eq 0 ]]; then
    return 0
  fi

  for dotpkg in "${DOTPKGS[@]}"; do
    normalized="$(normalize_dotpkg "${dotpkg}")"
    normalized_dotpkgs+=("${normalized}")
  done

  DOTPKGS=("${normalized_dotpkgs[@]}")
}

validate_dotpkgs() {
  local dotpkg

  if [[ "${#DOTPKGS[@]}" -eq 0 ]]; then
    return 0
  fi

  for dotpkg in "${DOTPKGS[@]}"; do
    if [[ ! -d "${dotpkg}" ]]; then
      abort "dot package not found: ${dotpkg}"
    fi
  done
}

ssh_key_spec_base() {
  local ssh_key="$1"

  printf "%s" "${ssh_key%%:*}"
}

ssh_key_spec_filename_override() {
  local ssh_key="$1"

  if [[ "${ssh_key}" == *:* ]]; then
    printf "%s" "${ssh_key#*:}"
  fi
}

ssh_key_spec_vault() {
  local base

  base="$(ssh_key_spec_base "$1")"
  printf "%s" "${base%%/*}"
}

ssh_key_spec_item() {
  local base

  base="$(ssh_key_spec_base "$1")"
  printf "%s" "${base#*/}"
}

ssh_key_filename() {
  local filename_override

  filename_override="$(ssh_key_spec_filename_override "$1")"
  if [[ -n "${filename_override}" ]]; then
    printf "%s" "${filename_override}"
  else
    ssh_key_spec_item "$1"
  fi
}

ssh_key_secret_ref() {
  local vault
  local item

  vault="$(ssh_key_spec_vault "$1")"
  item="$(ssh_key_spec_item "$1")"
  printf "op://%s/%s/private key?ssh-format=openssh" "${vault}" "${item}"
}

ssh_key_destination_path() {
  local filename

  filename="$(ssh_key_filename "$1")"
  printf "%s/.ssh/%s" "${TARGET}" "${filename}"
}

validate_ssh_key_spec() {
  local ssh_key="$1"
  local base
  local vault
  local item
  local filename_override

  base="$(ssh_key_spec_base "${ssh_key}")"
  vault="$(ssh_key_spec_vault "${ssh_key}")"
  item="$(ssh_key_spec_item "${ssh_key}")"
  filename_override="$(ssh_key_spec_filename_override "${ssh_key}")"

  if [[ -z "${base}" ]] || [[ "${base}" != */* ]] || [[ -z "${vault}" ]] || [[ -z "${item}" ]] || [[ "${item}" == *"/"* ]]; then
    abort "ssh key must use vault/item[:filename] format: ${ssh_key}"
  fi

  if [[ "${ssh_key}" == *:* ]] && [[ -z "${filename_override}" ]]; then
    abort "ssh key filename override cannot be empty: ${ssh_key}"
  fi

  if [[ -n "${filename_override}" ]] && [[ "${filename_override}" == *"/"* || "${filename_override}" == *":"* || "${filename_override}" == "." || "${filename_override}" == ".." ]]; then
    abort "ssh key filename override must be a single filename: ${ssh_key}"
  fi
}

validate_ssh_keys() {
  local ssh_key
  local filename
  local -a seen_filenames=()

  if [[ "${#SSH_KEYS[@]}" -eq 0 ]]; then
    return 0
  fi

  for ssh_key in "${SSH_KEYS[@]}"; do
    validate_ssh_key_spec "${ssh_key}"

    filename="$(ssh_key_filename "${ssh_key}")"
    if array_contains "${filename}" seen_filenames; then
      abort "ssh key destination filename is duplicated: ${filename}"
    fi

    seen_filenames+=("${filename}")
  done
}

if [[ -z "${TARGET}" ]] && [[ "${CHECK_CORE:-0}" != "1" ]]; then
  abort "HOME must be set before bootbox can configure the current user."
fi
if [[ -n "${TARGET}" ]]; then
  TARGET="$(normalize_local_path "${TARGET}")"
fi
normalize_brewfiles
validate_brewfiles
normalize_dotpkgs
validate_dotpkgs
validate_ssh_keys
BREWFILES_CSV="$(array_join "," BREWFILES)"
DOTPKGS_CSV="$(array_join "," DOTPKGS)"
SSH_KEYS_CSV="$(array_join "," SSH_KEYS)"

get_abs_dir() {
  local file="$1"
  cd "$(dirname "$file")" || exit 1
  pwd
}

detect_arch() {
  local arch
  arch="$(/usr/bin/uname -m || /usr/bin/arch || uname -m || arch)"
  if [[ "${arch}" == "arm64" ]] || [[ "${arch}" == "aarch64" ]]; then
    DETECTED_ARCH="arm64"
  elif [[ "${arch}" == "x86_64" ]] || [[ "${arch}" == "x64" ]]; then
    DETECTED_ARCH="x64"
  else
    DETECTED_ARCH="${arch}"
  fi
}

detect_os() {
  local os
  os="$(uname)"
  if [[ "${os}" == "Darwin" ]]; then
    DETECTED_OS="macos"
  elif [[ "${os}" == "Linux" ]]; then
    DETECTED_OS="linux"
  else
    DETECTED_OS="${os}"
  fi
}

default_homebrew_prefix() {
  local os="$1"
  local arch="$2"

  if [[ "${os}" == "linux" ]]; then
    echo "/home/linuxbrew/.linuxbrew"
  elif [[ "${arch}" == "arm64" ]]; then
    echo "/opt/homebrew"
  else
    echo "/usr/local"
  fi
}

# core packages that should be present regardless of any user-provided Brewfile
declare -a BOOTBOX_CORE_BREW_PACKAGES=(
  "formula|git|git"
  "cask|1password-cli@beta|op"
  "formula|curl|curl"
  "formula|zsh|zsh"
  "formula|jq|jq"
  "formula|stow|stow"
)

# GET THE LTF right away once we know we are not exiting through usage/version.
if ! BOOTBOX_TMPFILE="$(mktemp -t bootbox.XXXXXX)"; then
  abort "could not create a bootbox temporary file in ${TMPDIR:-the system temporary directory}."
fi

# derive the rest of the runtime defaults after argument parsing
detect_arch
detect_os

ARCH="$(env_value BOOTBOX_ARCH TANAAB_ARCH "$DETECTED_ARCH")"
OS="$(env_value BOOTBOX_OS TANAAB_OS "$DETECTED_OS")"
HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-"$(default_homebrew_prefix "$OS" "$ARCH")"}"
HOMEBREW_INSTALLER_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
BOOTBOX_TMPDIR=$(get_abs_dir "$BOOTBOX_TMPFILE")

# USER isn't always set so provide a fall back for the installer and subprocesses.
if [[ -z "${USER-}" ]]; then
  USER="$(chomp "$(id -un)")"
  export USER
fi

# redefine this one
abort() {
  printf "${tty_red}error${tty_reset}: %s\n" "$(chomp "$1")" >&2
  exit 1
}

abort_multi() {
  while read -r line; do
    printf "${tty_red}error${tty_reset}: %s\n" "$(chomp "$line")" >&2
  done <<< "$@"
  exit 1
}

chomp() {
  printf "%s" "${1/"$'\n'"/}"
}

debug_enabled() {
  value_enabled "${DEBUG:-}"
}

force_enabled() {
  value_enabled "${FORCE:-}"
}

quiet_enabled() {
  value_enabled "${QUIET:-}"
}

no_sudo_enabled() {
  value_enabled "${NO_SUDO:-}"
}

external_sudo_enabled() {
  value_enabled "${EXTERNAL_SUDO:-}"
}

sudo_enabled() {
  ! no_sudo_enabled
}

check_core_mode() {
  [[ "${CHECK_CORE:-0}" == "1" ]]
}

# set debug-related envvars for child processes
if debug_enabled; then
  export HOMEBREW_DEBUG=1
fi

debug() {
  if debug_enabled; then
    printf "${tty_dim}debug${tty_reset} %s\n" "$(shell_join "$@")" >&2
  fi
}

# shellcheck disable=SC2329
debug_multi() {
  if debug_enabled; then
    while read -r line; do
      debug "$1 $line"
    done <<< "$@"
  fi
}

log() {
  if quiet_enabled; then
    return 0
  fi

  printf "%s\n" "$(shell_join "$@")"
}

shell_join() {
  local arg
  printf "%s" "${1:-}"
  shift
  for arg in "$@"; do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

warn() {
  printf "${tty_yellow}warn${tty_reset}: %s\n" "$(chomp "$@")" >&2
}

# shellcheck disable=SC2329
warn_multi() {
  while read -r line; do
    warn "${line}"
  done <<< "$@"
}

# print version of script
debug "running ${SCRIPT_NAME} script version: ${SCRIPT_VERSION}"

# debug raw options
# these are options that have not yet been validated or mutated e.g. the ones the user has supplied or defaults
debug raw CI="${CI:-}"
debug raw NONINTERACTIVE="${NONINTERACTIVE:-}"
debug raw ARCH="$ARCH"
debug raw BREWFILES="$(array_join "," BREWFILES)"
debug raw DOTPKGS="$(array_join "," DOTPKGS)"
debug raw DEBUG="$DEBUG"
debug raw FORCE="$FORCE"
debug raw EXTERNAL_SUDO="$EXTERNAL_SUDO"
debug raw SSH_KEYS="$(array_join "," SSH_KEYS)"
debug raw OP_TOKEN="$(op_token_for_display)"
debug raw HOMEBREW_PREFIX="$HOMEBREW_PREFIX"
debug raw TARGET="$TARGET"
debug raw OS="$OS"
debug raw USER="$USER"
debug raw TMPFILE="$BOOTBOX_TMPFILE"
debug raw TMPDIR="$BOOTBOX_TMPDIR"

#######################################################################  tool-verification

# precautions
unset HAVE_SUDO_ACCESS
unset BREW
unset OP_CLI
unset BREW_NEEDS_INSTALL
unset HOMEBREW_ACCESS_INVALID
unset HOMEBREW_ACCESS_ERROR_PATH
unset BREWFILES_NEED_INSTALL
unset SSH_KEYS_NEED_INSTALL
unset DOTPKGS_NEED_STOW
unset EFFECTIVE_BREWFILE
unset DOTPKG_BACKUP_DIR
unset STOW

declare -a PLANNED_ACTIONS=()
declare -a PLANNED_SUDO_REASONS=()
declare -a CORE_BREW_FORMULAS_TO_INSTALL=()
declare -a CORE_BREW_CASKS_TO_INSTALL=()
declare -a CORE_BREW_CASK_DISPLAY_TO_INSTALL=()
declare -a CORE_BREW_DISPLAY_TO_INSTALL=()
declare -a RESOLVED_BREWFILES=()
declare -a SSH_KEY_DISPLAY_TO_INSTALL=()
declare -a SSH_KEY_DISPLAY_TO_OVERWRITE=()
declare -a DOTPKGS_TO_STOW=()
declare -a DOTPKG_CONFLICT_TARGETS=()
declare -a CURRENT_DOTPKG_CONFLICT_TARGETS=()

plan_action() {
  PLANNED_ACTIONS+=("$1")
}

have_planned_actions() {
  [[ "${#PLANNED_ACTIONS[@]}" -gt 0 ]]
}

show_planned_actions() {
  if ! have_planned_actions; then
    return 0
  fi

  log "${tty_bold}this script is about to:${tty_reset}"
  log

  local action
  for action in "${PLANNED_ACTIONS[@]}"; do
    log "  - ${action}"
  done
}

finish_noop() {
  log "${tty_bold}nothing to do${tty_reset}. ${tty_green}no changes are needed right now${tty_reset}."
  exit 0
}

find_tool() {
  if [[ $# -ne 1 ]]; then
    return 1
  fi

  local executable
  while read -r executable; do
    if [[ "${executable}" != /* ]]; then
      warn "Ignoring ${executable} (relative paths don't work)"
    elif "test_$1" "${executable}"; then
      echo "${executable}"
      break
    fi
  done < <(type -aP "$1")
}

executable_available() {
  type -P "$1" >/dev/null 2>&1
}

# shellcheck disable=SC2329
test_brew() {
  if [[ ! -x "$1" ]]; then
    return 1
  fi

  "$1" --version &>/dev/null
}

# shellcheck disable=SC2329
test_stow() {
  if [[ ! -x "$1" ]]; then
    return 1
  fi

  "$1" --version &>/dev/null
}

# shellcheck disable=SC2329
test_op() {
  if [[ ! -x "$1" ]]; then
    return 1
  fi

  "$1" --version &>/dev/null
}

brew_formula_installed() {
  "${BREW}" list --formula "$1" &>/dev/null
}

brew_cask_installed() {
  "${BREW}" list --cask "$1" &>/dev/null
}

find_first_existing_parent() {
  local dir="$1"

  while [[ ! -d "$dir" ]]; do
    dir=$(dirname "$dir")
  done

  echo "$dir"
}

directory_is_writable() {
  [[ -d "$1" ]] && [[ -r "$1" ]] && [[ -w "$1" ]] && [[ -x "$1" ]]
}

path_parent_directory() {
  find_first_existing_parent "$(dirname "$1")"
}

path_is_owned_by_current_user() {
  { [[ -e "$1" ]] || [[ -L "$1" ]]; } \
    && [[ -O "$1" ]]
}

validate_temporary_directory() {
  if ! directory_is_writable "${BOOTBOX_TMPDIR}"; then
    abort "bootbox temporary directory is not writable: ${BOOTBOX_TMPDIR}"
  fi
}

validate_user_home() {
  if [[ ! -d "${TARGET}" ]]; then
    abort "current user home directory does not exist: ${TARGET}."
  fi

  if ! path_is_owned_by_current_user "${TARGET}"; then
    abort "current user home directory is not owned by ${USER}: ${TARGET}."
  fi

  if ! directory_is_writable "${TARGET}"; then
    abort "current user home directory is not readable, writable, and traversable: ${TARGET}."
  fi
}

plan_sudo_requirement() {
  append_unique_array_value PLANNED_SUDO_REASONS "$1"
}

planned_operations_require_sudo() {
  [[ "${#PLANNED_SUDO_REASONS[@]}" -gt 0 ]]
}

planned_sudo_reasons() {
  array_join "; " PLANNED_SUDO_REASONS
}

plan_sudo_requirements() {
  local reason

  PLANNED_SUDO_REASONS=()

  if [[ "${BREW_NEEDS_INSTALL:-0}" == "1" ]]; then
    plan_sudo_requirement "Homebrew installation may require elevation"
  fi

  if planned_operations_require_sudo; then
    for reason in "${PLANNED_SUDO_REASONS[@]}"; do
      debug "sudo required: ${reason}"
    done
  elif [[ -n "${BREWFILES_NEED_INSTALL:-}" ]] \
    && [[ "${BREW_NEEDS_INSTALL:-0}" != "1" ]] \
    && [[ "${#CORE_BREW_DISPLAY_TO_INSTALL[@]}" -eq 0 ]] \
    && [[ -z "${SSH_KEYS_NEED_INSTALL:-}" ]] \
    && [[ -z "${DOTPKGS_NEED_STOW:-}" ]]; then
    debug "sudo not required: brewfile-only plan has no privileged file operations"
  else
    debug "sudo not required: planned operations have no privileged file operations"
  fi
}

find_homebrew() {
  local candidate
  local -a candidates=()

  if [[ -n "${HOMEBREW_PREFIX-}" ]]; then
    candidates+=("${HOMEBREW_PREFIX}/bin/brew")
  fi

  if [[ "${OS}" == "linux" ]]; then
    candidates+=("/home/linuxbrew/.linuxbrew/bin/brew")
  else
    candidates+=("/opt/homebrew/bin/brew" "/usr/local/bin/brew")
  fi

  for candidate in "${candidates[@]}"; do
    if test_brew "${candidate}"; then
      echo "${candidate}"
      return 0
    fi
  done

  find_tool brew
}

user_is_macos_admin() {
  [[ " $(/usr/bin/id -Gn) " == *" admin "* ]]
}

user_is_linux_sudoer() {
  local groups

  groups=" $(/usr/bin/id -Gn) "
  [[ "${groups}" == *" sudo "* ]] || [[ "${groups}" == *" wheel "* ]]
}

user_appears_sudo_capable() {
  if [[ "${OS}" == "macos" ]]; then
    user_is_macos_admin
  else
    user_is_linux_sudoer
  fi
}

have_sudo_access() {
  if no_sudo_enabled; then
    HAVE_SUDO_ACCESS="1"
    return 1
  fi

  if [[ -n "${HAVE_SUDO_ACCESS-}" ]]; then
    return "${HAVE_SUDO_ACCESS}"
  fi

  if external_sudo_enabled; then
    if sudo_credential_active; then
      HAVE_SUDO_ACCESS="0"
    else
      HAVE_SUDO_ACCESS="1"
    fi
    return "${HAVE_SUDO_ACCESS}"
  fi

  if [[ ! -x "/usr/bin/sudo" ]]; then
    HAVE_SUDO_ACCESS="1"
  elif sudo_credential_active || user_appears_sudo_capable; then
    HAVE_SUDO_ACCESS="0"
  else
    HAVE_SUDO_ACCESS="1"
  fi

  if [[ "${HAVE_SUDO_ACCESS}" == "1" ]]; then
    debug "${USER} does not appear to have sudo access!"
  else
    debug "${USER} has sudo access"
  fi

  return "${HAVE_SUDO_ACCESS}"
}

sudo_credential_active() {
  [[ -x "/usr/bin/sudo" ]] && /usr/bin/sudo -N -n -v >/dev/null 2>&1
}

sudo_version() {
  local sudo_version_output

  sudo_version_output="$(LC_ALL=C /usr/bin/sudo -V 2>/dev/null || true)"
  sudo_version_output="${sudo_version_output%%$'\n'*}"
  if [[ "${sudo_version_output}" =~ ^Sudo[[:space:]]version[[:space:]]([0-9]+\.[0-9]+\.[0-9]+) ]]; then
    printf "%s" "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
}

validate_sudo_version() {
  local installed_sudo_version

  if [[ ! -x "/usr/bin/sudo" ]]; then
    return 0
  fi

  installed_sudo_version="$(sudo_version || true)"
  if [[ -z "${installed_sudo_version}" ]]; then
    abort_multi "$(cat <<EOABORT
could not determine the sudo version at /usr/bin/sudo.
sudo ${REQUIRED_SUDO_VERSION} or newer is required when bootbox installs Homebrew.
upgrade sudo or install Homebrew from a privileged machine-prep layer first.
EOABORT
)"
  fi

  if ! version_compare_three_part "${installed_sudo_version}" "${REQUIRED_SUDO_VERSION}"; then
    abort_multi "$(cat <<EOABORT
sudo ${REQUIRED_SUDO_VERSION} or newer is required when bootbox installs Homebrew.
found sudo ${installed_sudo_version} at /usr/bin/sudo.
upgrade sudo or install Homebrew from a privileged machine-prep layer first.
EOABORT
)"
  fi

  debug "sudo ${installed_sudo_version} satisfies the ${REQUIRED_SUDO_VERSION} minimum"
}

validate_external_sudo_credential() {
  if sudo_credential_active; then
    HAVE_SUDO_ACCESS="0"
    return 0
  fi

  abort_multi "$(cat <<EOABORT
bootbox external sudo mode requires an active sudo credential.
the planned operation requires elevation: $(planned_sudo_reasons).
the calling process must run sudo -v and maintain the credential before invoking bootbox.
EOABORT
)"
}

load_homebrew_shellenv() {
  local brew="$1"
  local prefix
  local shellenv

  shellenv="$("${brew}" shellenv 2>/dev/null)" || return 1
  prefix="$("${brew}" --prefix 2>/dev/null)" || return 1
  eval "${shellenv}"
  HOMEBREW_PREFIX="${prefix}"
  BREW="${brew}"
}

homebrew_access_ok() {
  local brew="$1"
  local cellar
  local path
  local prefix
  local repository
  local -a managed_paths=()

  HOMEBREW_ACCESS_ERROR_PATH=""
  prefix="$("${brew}" --prefix 2>/dev/null)" || return 1
  repository="$("${brew}" --repository 2>/dev/null)" || return 1
  cellar="$("${brew}" --cellar 2>/dev/null)" || return 1
  HOMEBREW_PREFIX="${prefix}"

  managed_paths=(
    "${repository}"
    "${cellar}"
    "${prefix}/bin"
    "${prefix}/etc"
    "${prefix}/include"
    "${prefix}/lib"
    "${prefix}/opt"
    "${prefix}/sbin"
    "${prefix}/share"
    "${prefix}/var"
    "${prefix}/Caskroom"
    "${prefix}/Frameworks"
  )

  for path in "${managed_paths[@]}"; do
    if ! directory_is_writable "${path}"; then
      HOMEBREW_ACCESS_ERROR_PATH="${path}"
      return 1
    fi
  done

  return 0
}

abort_unmanageable_homebrew() {
  abort_multi "$(cat <<EOABORT
Homebrew at ${HOMEBREW_PREFIX} cannot be managed by ${USER}.
required Homebrew path is not readable, writable, and traversable: ${HOMEBREW_ACCESS_ERROR_PATH:-${HOMEBREW_PREFIX}}.
bootbox will not use sudo to repair an existing Homebrew installation.
run bootbox as the Homebrew-managing user or prepare trusted group access first; see the advanced guidance in the project README.
EOABORT
)"
}

abort_unloadable_homebrew() {
  abort_multi "$(cat <<EOABORT
Homebrew at ${BREW} could not load its shell environment.
repair the existing Homebrew installation or run bootbox as its managing user.
bootbox will not use sudo to repair an existing Homebrew installation.
EOABORT
)"
}

linux_glibc_version() {
  local getconf_path
  local glibc_output
  local ldd_path

  getconf_path="$(type -P getconf || true)"
  if [[ -n "${getconf_path}" ]]; then
    glibc_output="$("${getconf_path}" GNU_LIBC_VERSION 2>/dev/null || true)"
    if [[ "${glibc_output}" =~ ^glibc[[:space:]]+([0-9]+)\.([0-9]+) ]]; then
      printf "%s.%s" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
      return 0
    fi
  fi

  ldd_path="$(type -P ldd || true)"
  if [[ -z "${ldd_path}" ]]; then
    return 1
  fi

  glibc_output="$("${ldd_path}" --version 2>&1 || true)"
  glibc_output="${glibc_output%%$'\n'*}"
  if [[ "${glibc_output}" != *GLIBC* ]] && [[ "${glibc_output}" != *"GNU libc"* ]]; then
    return 1
  fi
  if [[ "${glibc_output}" =~ ([0-9]+)\.([0-9]+) ]]; then
    printf "%s.%s" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  fi

  return 1
}

validate_linux_homebrew_prerequisites() {
  local glibc_version
  local message
  local requirement
  local -a missing_requirements=()

  if [[ -z "$(find_tool git)" ]]; then
    missing_requirements+=("git ${REQUIRED_GIT_VERSION} or newer")
  fi
  if ! executable_available cc && ! executable_available gcc && ! executable_available clang; then
    missing_requirements+=("a C compiler (cc, gcc, or clang)")
  fi
  for requirement in make file ps; do
    if ! executable_available "${requirement}"; then
      missing_requirements+=("${requirement}")
    fi
  done

  glibc_version="$(linux_glibc_version || true)"
  if [[ -z "${glibc_version}" ]] || ! version_compare "${glibc_version}" "${REQUIRED_GLIBC_VERSION}"; then
    missing_requirements+=("glibc ${REQUIRED_GLIBC_VERSION} or newer")
  fi

  if [[ "${#missing_requirements[@]}" -eq 0 ]]; then
    debug "linux Homebrew prerequisites are available"
    return 0
  fi

  message="linux Homebrew prerequisites are missing or unusable:"
  for requirement in "${missing_requirements[@]}"; do
    message+=$'\n'"- ${requirement}"
  done
  message+=$'\n'"install the equivalent system dependencies for your Linux distribution, then rerun bootbox."
  message+=$'\n'"see https://docs.brew.sh/Homebrew-on-Linux#requirements for upstream requirements."
  abort_multi "${message}"
}

queue_core_brew_package() {
  local type="$1"
  local package="$2"
  local display="$3"

  CORE_BREW_DISPLAY_TO_INSTALL+=("${display}")

  if [[ "${type}" == "formula" ]]; then
    CORE_BREW_FORMULAS_TO_INSTALL+=("${package}")
  elif [[ "${type}" == "cask" ]]; then
    CORE_BREW_CASKS_TO_INSTALL+=("${package}")
    CORE_BREW_CASK_DISPLAY_TO_INSTALL+=("${display}")
  else
    abort "unknown core homebrew package type: ${type}"
  fi
}

plan_homebrew() {
  BREW="$(find_homebrew || true)"

  if [[ -n "${BREW}" ]]; then
    if ! homebrew_access_ok "${BREW}"; then
      if check_core_mode; then
        HOMEBREW_ACCESS_INVALID="1"
        return 0
      fi
      abort_unmanageable_homebrew
    fi
    if ! load_homebrew_shellenv "${BREW}"; then
      if check_core_mode; then
        HOMEBREW_ACCESS_INVALID="1"
        return 0
      fi
      abort_unloadable_homebrew
    fi
    debug "using Homebrew at ${BREW}"
    return 0
  fi

  debug "Homebrew was not found in the expected locations or in PATH"
  BREW_NEEDS_INSTALL="1"
  plan_action "${tty_tp}install${tty_reset} ${tty_ts}homebrew${tty_reset} ${tty_dim}using the official installer (expected prefix: ${tty_ts}${HOMEBREW_PREFIX}${tty_dim})${tty_reset}"
}

install_homebrew() {
  local installer="${BOOTBOX_TMPDIR}/homebrew-install.sh"

  log "${tty_tp}installing${tty_reset} ${tty_ts}homebrew${tty_reset} ${tty_dim}because it is not installed${tty_reset}"
  execute "${CURL}" \
    --fail \
    --location \
    --silent \
    --show-error \
    --output "${installer}" \
    "${HOMEBREW_INSTALLER_URL}"
  execute chmod +x "${installer}"

  if [[ -n "${NONINTERACTIVE-}" ]]; then
    execute env NONINTERACTIVE=1 CI="${CI:-1}" /bin/bash "${installer}"
  else
    execute env NONINTERACTIVE=1 /bin/bash "${installer}"
  fi

  BREW="$(find_homebrew || true)"
  if [[ -z "${BREW}" ]]; then
    abort "homebrew install finished but brew could not be found afterwards."
  fi

  if ! homebrew_access_ok "${BREW}"; then
    abort_unmanageable_homebrew
  fi
  if ! load_homebrew_shellenv "${BREW}"; then
    abort_unloadable_homebrew
  fi
  HOMEBREW_INSTALLED_BY_BOOTBOX="1"
  log "${tty_bold}installed${tty_reset} ${tty_green}homebrew${tty_reset}"
  debug "using Homebrew at ${BREW}"
}

resolve_homebrew_shell_setup() {
  HOMEBREW_SHELLENV_SUFFIX=""

  case "${SHELL-}" in
    */bash*)
      HOMEBREW_SHELLENV_SUFFIX=" bash"
      if [[ "${OS}" == "linux" ]]; then
        HOMEBREW_SHELL_RCFILE="${TARGET}/.bashrc"
      else
        HOMEBREW_SHELL_RCFILE="${TARGET}/.bash_profile"
      fi
      ;;
    */zsh*)
      HOMEBREW_SHELLENV_SUFFIX=" zsh"
      if [[ "${OS}" == "linux" ]]; then
        HOMEBREW_SHELL_RCFILE="${ZDOTDIR:-"${TARGET}"}/.zshrc"
      else
        HOMEBREW_SHELL_RCFILE="${ZDOTDIR:-"${TARGET}"}/.zprofile"
      fi
      ;;
    */fish*)
      HOMEBREW_SHELLENV_SUFFIX=" fish"
      HOMEBREW_SHELL_RCFILE="${TARGET}/.config/fish/config.fish"
      ;;
    *)
      HOMEBREW_SHELL_RCFILE="${ENV:-"${TARGET}/.profile"}"
      ;;
  esac
}

show_homebrew_shellenv_reminder() {
  if [[ "${HOMEBREW_INSTALLED_BY_BOOTBOX:-0}" != "1" ]]; then
    return 0
  fi
  if PATH="${INHERITED_PATH}" type -P brew >/dev/null 2>&1; then
    return 0
  fi

  resolve_homebrew_shell_setup
  if [[ -f "${HOMEBREW_SHELL_RCFILE}" ]] &&
    grep -qs "eval \"\$(${HOMEBREW_PREFIX}/bin/brew shellenv[^\"]*)\"" "${HOMEBREW_SHELL_RCFILE}"; then
    return 0
  fi

  log
  log "${tty_bold}add Homebrew to future shells${tty_reset}"
  log "add this line to ${tty_ts}${HOMEBREW_SHELL_RCFILE}${tty_reset}:"
  log "  ${tty_green}eval \"\$(${HOMEBREW_PREFIX}/bin/brew shellenv${HOMEBREW_SHELLENV_SUFFIX})\"${tty_reset}"
}

plan_core_homebrew_packages() {
  local entry
  local type
  local package
  local display

  CORE_BREW_FORMULAS_TO_INSTALL=()
  CORE_BREW_CASKS_TO_INSTALL=()
  CORE_BREW_CASK_DISPLAY_TO_INSTALL=()
  CORE_BREW_DISPLAY_TO_INSTALL=()

  for entry in "${BOOTBOX_CORE_BREW_PACKAGES[@]}"; do
    IFS='|' read -r type package display <<< "${entry}"

    if [[ "${BREW_NEEDS_INSTALL:-0}" == "1" ]]; then
      queue_core_brew_package "${type}" "${package}" "${display}"
    elif [[ "${type}" == "formula" ]] && ! brew_formula_installed "${package}"; then
      queue_core_brew_package "${type}" "${package}" "${display}"
    elif [[ "${type}" == "cask" ]] && ! brew_cask_installed "${package}"; then
      queue_core_brew_package "${type}" "${package}" "${display}"
    fi
  done

  if [[ "${#CORE_BREW_DISPLAY_TO_INSTALL[@]}" -gt 0 ]]; then
    debug "missing core Homebrew packages: $(array_join ", " CORE_BREW_DISPLAY_TO_INSTALL)"
    plan_action "${tty_tp}install${tty_reset} core homebrew packages: ${tty_ts}$(array_join ", " CORE_BREW_DISPLAY_TO_INSTALL)${tty_reset}"
  elif [[ "${BREW_NEEDS_INSTALL:-0}" != "1" ]]; then
    debug "core Homebrew packages are already installed"
  fi
}

run_check_core() {
  debug "running hidden --check-core mode"
  plan_homebrew

  if [[ "${HOMEBREW_ACCESS_INVALID:-0}" == "1" ]]; then
    debug "check-core result: Homebrew is not manageable by ${USER}"
    exit 1
  fi

  plan_core_homebrew_packages

  if [[ "${BREW_NEEDS_INSTALL:-0}" == "1" ]]; then
    debug "check-core result: Homebrew is missing"
    exit 1
  fi

  if [[ "${#CORE_BREW_DISPLAY_TO_INSTALL[@]}" -gt 0 ]]; then
    debug "check-core result: core Homebrew packages are missing"
    exit 1
  fi

  debug "check-core result: core requirements are satisfied"
  exit 0
}

install_core_homebrew_packages() {
  if [[ "${#CORE_BREW_FORMULAS_TO_INSTALL[@]}" -gt 0 ]]; then
    log "${tty_tp}installing${tty_reset} ${tty_dim}core homebrew formulas:${tty_reset} ${tty_ts}$(array_join ", " CORE_BREW_FORMULAS_TO_INSTALL)${tty_reset}"
    execute "${BREW}" install "${CORE_BREW_FORMULAS_TO_INSTALL[@]}"
  fi

  if [[ "${#CORE_BREW_CASKS_TO_INSTALL[@]}" -gt 0 ]]; then
    log "${tty_tp}installing${tty_reset} ${tty_dim}core homebrew casks:${tty_reset} ${tty_ts}$(array_join ", " CORE_BREW_CASK_DISPLAY_TO_INSTALL)${tty_reset}"
    execute "${BREW}" install --cask "${CORE_BREW_CASKS_TO_INSTALL[@]}"
  fi
}

fetch_brewfile_url() {
  local url="$1"
  local destination

  destination="$(mktemp "${BOOTBOX_TMPDIR}/brewfile-url.XXXXXX")"
  debug "fetching brewfile ${url} to ${destination}"

  if ! "${CURL}" \
    --fail \
    --location \
    --silent \
    --show-error \
    --output "${destination}" \
    "${url}"; then
    abort "failed to fetch brewfile: ${url}"
  fi

  printf "%s" "${destination}"
}

resolve_brewfile_source() {
  local brewfile="$1"

  if brewfile_is_url "${brewfile}"; then
    fetch_brewfile_url "${brewfile}"
  else
    printf "%s" "${brewfile}"
  fi
}

resolve_brewfiles() {
  local brewfile
  local resolved_brewfile

  RESOLVED_BREWFILES=()

  if [[ "${#BREWFILES[@]}" -eq 0 ]]; then
    return 0
  fi

  for brewfile in "${BREWFILES[@]}"; do
    resolved_brewfile="$(resolve_brewfile_source "${brewfile}")"
    RESOLVED_BREWFILES+=("${resolved_brewfile}")
  done
}

prepare_effective_brewfile() {
  local source_brewfile
  local effective_brewfile

  EFFECTIVE_BREWFILE=""

  if [[ "${#RESOLVED_BREWFILES[@]}" -eq 0 ]]; then
    return 0
  fi

  effective_brewfile="$(mktemp "${BOOTBOX_TMPDIR}/brewfile-effective.XXXXXX")"
  : > "${effective_brewfile}"

  for source_brewfile in "${RESOLVED_BREWFILES[@]}"; do
    if [[ ! -f "${source_brewfile}" ]] || [[ ! -s "${source_brewfile}" ]]; then
      continue
    fi

    {
      printf "# source: %s\n" "${source_brewfile}"
      cat "${source_brewfile}"
      printf "\n"
    } >> "${effective_brewfile}"
  done

  EFFECTIVE_BREWFILE="${effective_brewfile}"
  debug "prepared effective brewfile at ${EFFECTIVE_BREWFILE}"
}

brewfile_has_entries() {
  if [[ -z "${1:-}" ]] || [[ ! -f "$1" ]]; then
    return 1
  fi

  grep -Eq '^[[:space:]]*[^#[:space:]]' "$1"
}

brew_bundle_check() {
  local brewfile="$1"
  local status

  "${BREW}" bundle check --file "${brewfile}" --no-upgrade >/dev/null 2>&1
  status="$?"

  if [[ "${status}" -eq 0 ]]; then
    return 0
  fi

  if [[ "${status}" -eq 1 ]]; then
    return 1
  fi

  abort "failed to check brew bundle state for ${brewfile}"
}

plan_brewfiles() {
  BREWFILES_NEED_INSTALL=""

  if [[ "${#BREWFILES[@]}" -eq 0 ]]; then
    return 0
  fi

  resolve_brewfiles
  prepare_effective_brewfile

  if ! brewfile_has_entries "${EFFECTIVE_BREWFILE:-}"; then
    debug "skipping brewfile install because there are no brew bundle entries"
    return 0
  fi

  if [[ "${BREW_NEEDS_INSTALL:-0}" == "1" ]]; then
    BREWFILES_NEED_INSTALL="1"
  elif ! brew_bundle_check "${EFFECTIVE_BREWFILE}"; then
    BREWFILES_NEED_INSTALL="1"
  fi

  if [[ -n "${BREWFILES_NEED_INSTALL:-}" ]]; then
    plan_action "${tty_tp}install${tty_reset} brewfile packages from: ${tty_ts}$(array_join ", " BREWFILES)${tty_reset}"
  fi
}

install_brewfiles() {
  if [[ -z "${BREWFILES_NEED_INSTALL:-}" ]]; then
    return 0
  fi

  if ! brewfile_has_entries "${EFFECTIVE_BREWFILE:-}"; then
    return 0
  fi

  if brew_bundle_check "${EFFECTIVE_BREWFILE}"; then
    debug "brewfile packages are already installed"
    return 0
  fi

  log "${tty_tp}installing${tty_reset} ${tty_dim}brewfile packages from:${tty_reset} ${tty_ts}$(array_join ", " BREWFILES)${tty_reset}"
  execute "${BREW}" bundle install --file "${EFFECTIVE_BREWFILE}" --no-upgrade
}

ensure_stow() {
  if [[ -n "${STOW:-}" ]] && test_stow "${STOW}"; then
    return 0
  fi

  STOW="$(find_tool stow || true)"
  [[ -n "${STOW}" ]]
}

ensure_op() {
  if [[ -n "${OP_CLI:-}" ]] && test_op "${OP_CLI}"; then
    return 0
  fi

  OP_CLI="$(find_tool op || true)"
  [[ -n "${OP_CLI}" ]]
}

ssh_dir_path() {
  printf "%s/.ssh" "${TARGET}"
}

ssh_dir_ready_for_private_keys() {
  local ssh_dir

  ssh_dir="$(ssh_dir_path)"

  if [[ -L "${ssh_dir}" ]]; then
    abort_multi "$(cat <<EOABORT
ssh key installation target is a symlinked directory: ${ssh_dir}
refusing to write private keys through a symlink. replace it with a real directory first.
EOABORT
)"
  fi

  if [[ -e "${ssh_dir}" ]] && [[ ! -d "${ssh_dir}" ]]; then
    abort "ssh key installation target exists but is not a directory: ${ssh_dir}"
  fi

  if [[ -d "${ssh_dir}" ]] && ! path_is_owned_by_current_user "${ssh_dir}"; then
    abort "ssh key installation target is not owned by ${USER}: ${ssh_dir}"
  fi
}

op_read_ssh_key_to_file() {
  local ssh_key="$1"
  local destination="$2"
  local secret_ref
  local ssh_key_base

  secret_ref="$(ssh_key_secret_ref "${ssh_key}")"
  ssh_key_base="$(ssh_key_spec_base "${ssh_key}")"
  debug "${tty_tp}running${tty_reset}" "${OP_CLI}" read "${secret_ref}" ">" "${destination}"

  if ! (
    umask 077
    /usr/bin/env \
      -u OP_CONNECT_HOST \
      -u OP_CONNECT_TOKEN \
      OP_SERVICE_ACCOUNT_TOKEN="${OP_TOKEN}" \
      "${OP_CLI}" read "${secret_ref}" > "${destination}"
  ); then
    abort "failed to read ssh key from 1password: ${ssh_key_base}"
  fi

  if [[ ! -s "${destination}" ]]; then
    abort "1password returned an empty ssh key: ${ssh_key_base}"
  fi
}

plan_ssh_keys() {
  local ssh_key
  local ssh_dir
  local destination_path
  local filename

  SSH_KEYS_NEED_INSTALL=""
  SSH_KEY_DISPLAY_TO_INSTALL=()
  SSH_KEY_DISPLAY_TO_OVERWRITE=()

  if [[ "${#SSH_KEYS[@]}" -eq 0 ]]; then
    return 0
  fi

  if [[ -z "${OP_TOKEN:-}" ]]; then
    abort_multi "$(cat <<EOABORT
ssh key installation requires a 1password service account token.
set BOOTBOX_OP_TOKEN or OP_SERVICE_ACCOUNT_TOKEN, or pass --op-token.
EOABORT
)"
  fi

  ssh_dir_ready_for_private_keys
  ssh_dir="$(ssh_dir_path)"

  for ssh_key in "${SSH_KEYS[@]}"; do
    filename="$(ssh_key_filename "${ssh_key}")"
    destination_path="$(ssh_key_destination_path "${ssh_key}")"
    append_unique_array_value SSH_KEY_DISPLAY_TO_INSTALL "${filename}"

    if [[ -e "${destination_path}" ]] || [[ -L "${destination_path}" ]]; then
      if [[ -d "${destination_path}" ]] && [[ ! -L "${destination_path}" ]]; then
        abort "ssh key destination exists as a directory: ${destination_path}"
      fi

      if ! force_enabled; then
        abort_multi "$(cat <<EOABORT
ssh key already exists: ${destination_path}
remove or back up the existing key first, or rerun with --force to overwrite it.
EOABORT
)"
      fi

      append_unique_array_value SSH_KEY_DISPLAY_TO_OVERWRITE "${filename}"
    fi
  done

  if [[ "${#SSH_KEY_DISPLAY_TO_INSTALL[@]}" -eq 0 ]]; then
    return 0
  fi

  SSH_KEYS_NEED_INSTALL="1"

  if [[ "${#SSH_KEY_DISPLAY_TO_OVERWRITE[@]}" -gt 0 ]]; then
    plan_action "${tty_tp}install${tty_reset} ssh keys into ${tty_ts}${ssh_dir}${tty_reset}: ${tty_ts}$(array_join ", " SSH_KEY_DISPLAY_TO_INSTALL)${tty_reset} ${tty_dim}(overwriting: $(array_join ", " SSH_KEY_DISPLAY_TO_OVERWRITE))${tty_reset}"
  else
    plan_action "${tty_tp}install${tty_reset} ssh keys into ${tty_ts}${ssh_dir}${tty_reset}: ${tty_ts}$(array_join ", " SSH_KEY_DISPLAY_TO_INSTALL)${tty_reset}"
  fi
}

install_ssh_keys() {
  local ssh_key
  local ssh_dir
  local destination_path
  local filename
  local key_tmpfile
  local installed_any="1"

  if [[ -z "${SSH_KEYS_NEED_INSTALL:-}" ]]; then
    return 0
  fi

  if ! ensure_op; then
    abort "1password cli is required for ssh key installation but could not be found."
  fi

  ssh_dir_ready_for_private_keys
  ssh_dir="$(ssh_dir_path)"
  auto_mkdirp "${ssh_dir}"
  auto_chmod 700 "${ssh_dir}"

  for ssh_key in "${SSH_KEYS[@]}"; do
    filename="$(ssh_key_filename "${ssh_key}")"
    destination_path="$(ssh_key_destination_path "${ssh_key}")"

    if [[ -e "${destination_path}" ]] || [[ -L "${destination_path}" ]]; then
      if [[ -d "${destination_path}" ]] && [[ ! -L "${destination_path}" ]]; then
        abort "ssh key destination exists as a directory: ${destination_path}"
      fi

      if ! force_enabled; then
        abort_multi "$(cat <<EOABORT
ssh key already exists: ${destination_path}
remove or back up the existing key first, or rerun with --force to overwrite it.
EOABORT
)"
      fi

      log "${tty_tp}installing${tty_reset} ssh key ${tty_ts}${filename}${tty_reset} ${tty_dim}into${tty_reset} ${tty_ts}${ssh_dir}${tty_reset} ${tty_dim}(overwriting existing key)${tty_reset}"
      auto_rm "${destination_path}"
    else
      log "${tty_tp}installing${tty_reset} ssh key ${tty_ts}${filename}${tty_reset} ${tty_dim}into${tty_reset} ${tty_ts}${ssh_dir}${tty_reset}"
    fi

    key_tmpfile="$(mktemp "${BOOTBOX_TMPDIR}/ssh-key.XXXXXX")"
    op_read_ssh_key_to_file "${ssh_key}" "${key_tmpfile}"
    auto_mv "${key_tmpfile}" "${destination_path}"
    auto_chmod 600 "${destination_path}"
    installed_any="0"
  done

  if [[ "${installed_any}" -eq 1 ]]; then
    return 0
  fi

  log "${tty_bold}installed${tty_reset} ssh keys into ${tty_green}${ssh_dir}${tty_reset}"
}

timestamp_now() {
  /bin/date +"%Y%m%d-%H%M%S"
}

simulate_dotpkg() {
  local dotpkg="$1"
  local dotpkg_parent
  local dotpkg_name

  dotpkg_parent="$(dirname "${dotpkg}")"
  dotpkg_name="$(basename "${dotpkg}")"

  "${STOW}" \
    --simulate \
    --verbose=1 \
    --dir "${dotpkg_parent}" \
    --target "${TARGET}" \
    "${dotpkg_name}" 2>&1
}

strip_stow_simulation_noise() {
  local output="$1"
  local line

  while IFS= read -r line; do
    if [[ "${line}" == "WARNING: in simulation mode so not modifying filesystem." ]]; then
      continue
    fi

    printf "%s\n" "${line}"
  done <<< "${output}"
}

stow_output_has_conflicts() {
  [[ "$1" == *"would cause conflicts:"* ]] || [[ "$1" == *" existing target "* ]]
}

extract_dotpkg_conflict_target() {
  local line="$1"
  local conflict_target=""

  if [[ "${line}" == *" existing target "* ]] && [[ "${line}" == *" since "* ]]; then
    conflict_target="${line#* existing target }"
    conflict_target="${conflict_target%% since *}"
  elif [[ "${line}" == *"existing target is not owned by stow:"* ]]; then
    conflict_target="${line##*: }"
  elif [[ "${line}" == *"existing target is stowed to a different package:"* ]]; then
    conflict_target="${line##*: }"
    conflict_target="${conflict_target%% => *}"
  fi

  printf "%s" "${conflict_target}"
}

collect_dotpkg_conflicts() {
  local array_name="$1"
  local output="$2"
  local line
  local conflict_target
  local found="1"

  while IFS= read -r line; do
    conflict_target="$(extract_dotpkg_conflict_target "${line}")"
    if [[ -n "${conflict_target}" ]]; then
      append_unique_array_value "${array_name}" "${conflict_target}"
      found="0"
    fi
  done <<< "${output}"

  return "${found}"
}

evaluate_dotpkg() {
  local dotpkg="$1"
  local simulate_output
  local cleaned_output
  local simulate_status

  CURRENT_DOTPKG_NEEDS_STOW=""
  CURRENT_DOTPKG_CONFLICT_TARGETS=()

  # Capture the simulation result through an if-condition so expected conflict exits
  # do not trip `set -e` before we can inspect the output and status.
  if simulate_output="$(simulate_dotpkg "${dotpkg}")"; then
    simulate_status="0"
  else
    simulate_status="$?"
  fi
  cleaned_output="$(strip_stow_simulation_noise "${simulate_output}")"

  if [[ -n "${cleaned_output}" ]]; then
    debug_multi "stow simulate ${dotpkg}:" "${cleaned_output}"
  fi

  if [[ "${simulate_status}" -eq 0 ]]; then
    if [[ -n "${cleaned_output}" ]]; then
      CURRENT_DOTPKG_NEEDS_STOW="1"
    fi
    return 0
  fi

  if [[ "${simulate_status}" -eq 1 ]] && stow_output_has_conflicts "${cleaned_output}"; then
    if ! collect_dotpkg_conflicts CURRENT_DOTPKG_CONFLICT_TARGETS "${cleaned_output}"; then
      abort_multi "$(cat <<EOABORT
failed to determine which files need backup for dot package: ${dotpkg}
${cleaned_output:-${simulate_output}}
EOABORT
)"
    fi

    CURRENT_DOTPKG_NEEDS_STOW="1"
    return 0
  fi

  abort_multi "$(cat <<EOABORT
failed to simulate stow for dot package: ${dotpkg}
${cleaned_output:-${simulate_output}}
EOABORT
)"
}

evaluate_dotpkgs() {
  local dotpkg
  local conflict_target

  DOTPKGS_TO_STOW=()
  DOTPKG_CONFLICT_TARGETS=()

  if [[ "${#DOTPKGS[@]}" -eq 0 ]]; then
    return 0
  fi

  if [[ ! -d "${TARGET}" ]]; then
    DOTPKGS_TO_STOW=("${DOTPKGS[@]}")
    return 0
  fi

  if ! ensure_stow; then
    return 1
  fi

  for dotpkg in "${DOTPKGS[@]}"; do
    evaluate_dotpkg "${dotpkg}"

    if [[ -n "${CURRENT_DOTPKG_NEEDS_STOW:-}" ]]; then
      append_unique_array_value DOTPKGS_TO_STOW "${dotpkg}"
      if [[ "${#CURRENT_DOTPKG_CONFLICT_TARGETS[@]}" -gt 0 ]]; then
        for conflict_target in "${CURRENT_DOTPKG_CONFLICT_TARGETS[@]}"; do
          append_unique_array_value DOTPKG_CONFLICT_TARGETS "${conflict_target}"
        done
      fi
    fi
  done
}

stow_dotpkg() {
  local dotpkg="$1"
  local dotpkg_parent
  local dotpkg_name

  dotpkg_parent="$(dirname "${dotpkg}")"
  dotpkg_name="$(basename "${dotpkg}")"

  execute "${STOW}" \
    --dir "${dotpkg_parent}" \
    --target "${TARGET}" \
    "${dotpkg_name}"
}

validate_dotpkg_conflict_access() {
  local conflict_target
  local source_path

  for conflict_target in "${DOTPKG_CONFLICT_TARGETS[@]}"; do
    source_path="${TARGET}/${conflict_target}"
    if ! directory_is_writable "$(path_parent_directory "${source_path}")"; then
      abort "dotpackage conflict cannot be replaced by ${USER}: ${source_path}"
    fi
  done
}

backup_dotpkg_conflicts() {
  local conflict_target
  local source_path
  local backup_path
  local moved_any="1"

  if [[ "${#CURRENT_DOTPKG_CONFLICT_TARGETS[@]}" -eq 0 ]]; then
    return 0
  fi

  for conflict_target in "${CURRENT_DOTPKG_CONFLICT_TARGETS[@]}"; do
    source_path="${TARGET}/${conflict_target}"

    if [[ ! -e "${source_path}" ]] && [[ ! -L "${source_path}" ]]; then
      continue
    fi

    if [[ -z "${DOTPKG_BACKUP_DIR:-}" ]]; then
      DOTPKG_BACKUP_DIR="${TARGET}/.tanaab-backups/stow-$(timestamp_now)"
    fi

    backup_path="${DOTPKG_BACKUP_DIR}/${conflict_target}"
    auto_mkdirp "${DOTPKG_BACKUP_DIR}"
    auto_mkdirp "$(dirname "${backup_path}")"

    if [[ -L "${source_path}" ]] && [[ -e "${source_path}" ]]; then
      auto_cp_follow "${source_path}" "${backup_path}"
      auto_rm "${source_path}"
    else
      auto_mv "${source_path}" "${backup_path}"
    fi

    moved_any="0"
  done

  return "${moved_any}"
}

plan_dotpkgs() {
  DOTPKGS_NEED_STOW=""
  DOTPKG_BACKUP_DIR=""

  if [[ "${#DOTPKGS[@]}" -eq 0 ]]; then
    return 0
  fi

  if ! evaluate_dotpkgs; then
    DOTPKGS_TO_STOW=("${DOTPKGS[@]}")
    DOTPKG_CONFLICT_TARGETS=()
  fi

  if [[ "${#DOTPKGS_TO_STOW[@]}" -eq 0 ]]; then
    return 0
  fi

  DOTPKGS_NEED_STOW="1"

  if [[ "${#DOTPKG_CONFLICT_TARGETS[@]}" -gt 0 ]]; then
    DOTPKG_BACKUP_DIR="${TARGET}/.tanaab-backups/stow-$(timestamp_now)"
    validate_dotpkg_conflict_access
    plan_action "${tty_tp}backup${tty_reset} conflicting dotfiles to ${tty_ts}${DOTPKG_BACKUP_DIR}${tty_reset}"
  fi

  plan_action "${tty_tp}stow${tty_reset} dot packages into ${tty_ts}${TARGET}${tty_reset}: ${tty_ts}$(array_join ", " DOTPKGS_TO_STOW)${tty_reset}"
}

install_dotpkgs() {
  local dotpkg
  local stowed_any="1"
  local backed_up_conflicts="1"

  if [[ -z "${DOTPKGS_NEED_STOW:-}" ]]; then
    return 0
  fi

  auto_mkdirp "${TARGET}"

  if ! ensure_stow; then
    abort "stow is required for dot package management but could not be found."
  fi

  for dotpkg in "${DOTPKGS[@]}"; do
    evaluate_dotpkg "${dotpkg}"

    if [[ -z "${CURRENT_DOTPKG_NEEDS_STOW:-}" ]]; then
      continue
    fi

    log "${tty_tp}stowing${tty_reset} ${tty_ts}${dotpkg}${tty_reset} ${tty_dim}into${tty_reset} ${tty_ts}${TARGET}${tty_reset}"

    if [[ "${#CURRENT_DOTPKG_CONFLICT_TARGETS[@]}" -gt 0 ]]; then
      if ! backup_dotpkg_conflicts; then
        abort "failed to back up conflicting dotfiles before stowing ${dotpkg}"
      fi
      backed_up_conflicts="0"
    fi

    stow_dotpkg "${dotpkg}"
    stowed_any="0"
  done

  if [[ "${stowed_any}" -eq 1 ]]; then
    debug "dot packages are already stowed"
    return 0
  fi

  if [[ -n "${DOTPKG_BACKUP_DIR:-}" ]] && [[ "${backed_up_conflicts}" -eq 0 ]]; then
    log "${tty_bold}backed up${tty_reset} conflicting dotfiles to ${tty_green}${DOTPKG_BACKUP_DIR}${tty_reset}"
  fi
}

major_minor() {
  echo "${1%%.*}.$(
    x="${1#*.}"
    echo "${x%%.*}"
  )"
}

# shellcheck disable=SC2329
test_curl() {
  if [[ ! -x "$1" ]]; then
    return 1
  fi
  if [[ "$1" == "/snap/bin/curl" ]]; then
    return 1
  fi

  local curl_version_output curl_name_and_version
  curl_version_output="$("$1" --version 2>/dev/null)"
  curl_name_and_version="${curl_version_output%% (*}"
  version_compare "$(major_minor "${curl_name_and_version##* }")" "$(major_minor "${REQUIRED_CURL_VERSION}")"
}

# shellcheck disable=SC2329
test_git() {
  local git_version_output

  if [[ ! -x "$1" ]]; then
    return 1
  fi

  git_version_output="$("$1" --version 2>/dev/null)"
  if [[ "${git_version_output}" =~ git[[:space:]]version[[:space:]]([0-9]+\.[0-9]+) ]]; then
    version_compare "${BASH_REMATCH[1]}" "$(major_minor "${REQUIRED_GIT_VERSION}")"
  else
    return 1
  fi
}

# returns true if maj.min a is greater than maj.min b
version_compare() (
  yy_a="$(echo "$1" | cut -d'.' -f1)"
  yy_b="$(echo "$2" | cut -d'.' -f1)"
  if [ "$yy_a" -lt "$yy_b" ]; then
    return 1
  fi
  if [ "$yy_a" -gt "$yy_b" ]; then
    return 0
  fi
  mm_a="$(echo "$1" | cut -d'.' -f2)"
  mm_b="$(echo "$2" | cut -d'.' -f2)"

  # trim leading zeros to accommodate CalVer
  mm_a="${mm_a#0}"
  mm_b="${mm_b#0}"

  if [ "${mm_a:-0}" -lt "${mm_b:-0}" ]; then
    return 1
  fi

  return 0
)

version_compare_three_part() {
  local actual_major actual_minor actual_patch
  local required_major required_minor required_patch

  if [[ ! "$1" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    return 1
  fi
  actual_major=$((10#${BASH_REMATCH[1]}))
  actual_minor=$((10#${BASH_REMATCH[2]}))
  actual_patch=$((10#${BASH_REMATCH[3]}))

  if [[ ! "$2" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    return 1
  fi
  required_major=$((10#${BASH_REMATCH[1]}))
  required_minor=$((10#${BASH_REMATCH[2]}))
  required_patch=$((10#${BASH_REMATCH[3]}))

  if ((actual_major != required_major)); then
    ((actual_major > required_major))
  elif ((actual_minor != required_minor)); then
    ((actual_minor > required_minor))
  else
    ((actual_patch >= required_patch))
  fi
}

if check_core_mode; then
  run_check_core
fi

# abort if we dont have curl, or the right version of it
if [[ -z "$(find_tool curl)" ]]; then
  abort_multi "$(cat <<EOABORT
You must install cURL ${REQUIRED_CURL_VERSION} or higher before using this installer.
EOABORT
)"
fi

# set curl
CURL=$(find_tool curl);
debug "using the cURL at ${CURL}"

####################################################################### pre-script errors

# abort if run as root
# @NOTE: this might change in the future but right now we do not understand all the complexities around this
if [[ "${EUID:-${UID}}" == "0" ]]; then
  abort "cannot run this script as root."
fi

# abort if unsupported os
if [[ "${OS}" != "macos" ]] && [[ "${OS}" != "linux" ]]; then
  abort_multi "$(cat <<EOABORT
this script only supports ${tty_ts}macOS${tty_reset} and ${tty_ts}Linux${tty_reset}; ${tty_red}${OS}${tty_reset} is not supported.
check the project README for current support details: ${tty_underline}${tty_magenta}https://github.com/tanaabased/bootbox${tty_reset}
EOABORT
)"
fi

# abort if unsupported arch
if [[ "${ARCH}" != "x64" ]] && [[ "${ARCH}" != "arm64" ]]; then
  abort_multi "$(cat <<EOABORT
this script currently only supports ${tty_ts}x64${tty_reset} and ${tty_ts}arm64${tty_reset} systems.
check the project README for current support details: ${tty_underline}${tty_magenta}https://github.com/tanaabased/bootbox${tty_reset}
EOABORT
)"
fi

# abort if macos version is too low
if [[ "${OS}" == "macos" ]]; then
  macos_version="$(major_minor "$(/usr/bin/sw_vers -productVersion)")"
  if ! version_compare "${macos_version}" "${MACOS_OLDEST_SUPPORTED}"; then
    abort_multi "$(cat <<EOABORT
your macOS version ${tty_red}${macos_version}${tty_reset} is ${tty_bold}too old${tty_reset}; minimum supported version is ${tty_ts}${MACOS_OLDEST_SUPPORTED}${tty_reset}.
check the project README for current support details: ${tty_underline}${tty_magenta}https://github.com/tanaabased/bootbox${tty_reset}
EOABORT
)"
  fi
fi

if external_sudo_enabled && no_sudo_enabled; then
  abort_multi "$(cat <<EOABORT
BOOTBOX_EXTERNAL_SUDO=1 cannot be combined with ${tty_bold}--no-sudo${tty_reset} or BOOTBOX_NO_SUDO=1.
choose either caller-managed sudo or no sudo, not both.
EOABORT
)"
fi

validate_temporary_directory
validate_user_home
plan_homebrew

if no_sudo_enabled && [[ "${BREW_NEEDS_INSTALL:-0}" == "1" ]]; then
  abort_multi "$(cat <<EOABORT
Homebrew is missing and bootbox is running with ${tty_bold}--no-sudo${tty_reset}.
install Homebrew from a privileged machine-prep layer first, then rerun bootbox without requiring sudo.
for more information on advanced usage rerun with --help or check out: ${tty_underline}${tty_magenta}https://github.com/tanaabased/bootbox${tty_reset}
EOABORT
)"
fi

if [[ "${OS}" == "linux" ]] && [[ "${BREW_NEEDS_INSTALL:-0}" == "1" ]]; then
  validate_linux_homebrew_prerequisites
fi

plan_core_homebrew_packages
plan_brewfiles
plan_ssh_keys
plan_dotpkgs

if ! have_planned_actions; then
  finish_noop
fi

plan_sudo_requirements

if planned_operations_require_sudo && sudo_enabled; then
  validate_sudo_version
fi

if planned_operations_require_sudo && external_sudo_enabled; then
  validate_external_sudo_credential
elif planned_operations_require_sudo && ! have_sudo_access; then
  abort_multi "$(cat <<EOABORT
${tty_bold}${USER}${tty_reset} cannot complete the planned operation without ${tty_bold}sudo${tty_reset}: $(planned_sudo_reasons).
rerun setup as an administrator or sudo-capable user, or install Homebrew from a privileged machine-prep layer first.
for more information on advanced usage rerun with --help or check out: ${tty_underline}${tty_magenta}https://github.com/tanaabased/bootbox${tty_reset}
EOABORT
)"
fi

####################################################################### pre-script warnings

interactive_tty_available() {
  [[ -r /dev/tty && -w /dev/tty ]] || [[ -t 0 ]]
}

interactive_tty_input() {
  if [[ -r /dev/tty && -w /dev/tty ]]; then
    printf "/dev/tty"
  else
    printf "/dev/stdin"
  fi
}

# Check if script is run non-interactively (e.g. CI)
# If it is run non-interactively we should not prompt for passwords.
# Always use single-quoted strings with `exp` expressions
# shellcheck disable=SC2016
if [[ -z "${NONINTERACTIVE-}" ]]; then
  if [[ -n "${CI-}" ]]; then
    warn 'running in non-interactive mode because $CI is set.'
    NONINTERACTIVE=1
  elif ! interactive_tty_available; then
    if [[ -z "${INTERACTIVE-}" ]];  then
      warn 'running in non-interactive mode because no interactive terminal is available.'
      NONINTERACTIVE=1
    else
      abort "cannot run interactive mode because no interactive terminal is available."
    fi
  elif [[ ! -t 0 ]]; then
    debug "${tty_tp}using${tty_reset} ${tty_ts}/dev/tty${tty_reset} for interactive input because stdin is not a tty."
  fi
else
  log "${tty_tp}running${tty_reset} in ${tty_ts}non-interactive mode${tty_reset} ${tty_dim}because \$NONINTERACTIVE is set${tty_reset}"
fi

####################################################################### script

getc() {
  local input_path
  local save_state

  input_path="$(interactive_tty_input)"
  save_state="$(/bin/stty -g < "${input_path}")"
  /bin/stty raw -echo < "${input_path}"
  IFS='' read -r -n 1 -d '' "$@" < "${input_path}"
  /bin/stty "${save_state}" < "${input_path}"
}

execute() {
  debug "${tty_tp}running${tty_reset}" "$@"
  if ! "$@"; then
    abort "$(printf "failed during: %s" "$(shell_join "$@")")"
  fi
}

execute_sudo() {
  local -a args=("$@")
  if sudo_enabled && [[ "${EUID:-${UID}}" != "0" ]] && have_sudo_access; then
    if external_sudo_enabled; then
      args=("-n" "${args[@]}")
    elif [[ -n "${SUDO_ASKPASS-}" ]]; then
      args=("-A" "${args[@]}")
    fi
    execute "/usr/bin/sudo" "${args[@]}"
  else
    execute "${args[@]}"
  fi
}

wait_for_user() {
  local c

  # Trap to clean up on Ctrl-C or exit
  trap 'if [[ -r /dev/tty ]]; then /bin/stty sane < /dev/tty; else /bin/stty sane; fi; tput sgr0; echo; exit 1' SIGINT

  echo
  echo "press ${tty_bold}RETURN${tty_reset}/${tty_bold}ENTER${tty_reset} to continue or any other key to abort:"
  getc c
  # we test for \r and \n because some stuff does \r instead
  if ! [[ "${c}" == $'\r' || "${c}" == $'\n' ]]; then
    exit 1
  fi
}

# shellcheck disable=SC2329
auto_mkdirp() {
  local dir="$1"

  if [[ -d "${dir}" ]]; then
    return 0
  fi

  execute mkdir -p "$dir"
}

# shellcheck disable=SC2329
auto_mv() {
  local source="$1"
  local dest="$2"

  execute mv -f "$source" "$dest"
}

# shellcheck disable=SC2329
auto_cp_follow() {
  local source="$1"
  local dest="$2"

  execute cp -RL "$source" "$dest"
}

# shellcheck disable=SC2329
auto_rm() {
  local path="$1"

  execute rm -f "$path"
}

# shellcheck disable=SC2329
auto_chmod() {
  local mode="$1"
  local path="$2"

  execute chmod "${mode}" "$path"
}

# Inspect standalone sudo state once so bootbox can preserve a pre-existing credential.
SUDO_CREDENTIAL_ACTIVE_BEFORE_BOOTBOX=""
if sudo_enabled && ! external_sudo_enabled && planned_operations_require_sudo && [[ -x /usr/bin/sudo ]]; then
  if sudo_credential_active; then
    SUDO_CREDENTIAL_ACTIVE_BEFORE_BOOTBOX="1"
  else
    trap '/usr/bin/sudo -k' EXIT
  fi
fi

# Things can fail later if `pwd` doesn't exist.
# Also sudo prints a warning message for no good reason
cd "/usr" || exit 1

# summarize planned changes only when the user can still choose to continue
if [[ -z "${NONINTERACTIVE-}" ]] && have_planned_actions; then
  show_planned_actions
  wait_for_user
fi

# flag for password here if needed
if sudo_enabled && ! external_sudo_enabled && planned_operations_require_sudo; then
  if [[ -z "${SUDO_CREDENTIAL_ACTIVE_BEFORE_BOOTBOX}" ]]; then
    log "${tty_tp}enter${tty_reset} your ${tty_ts}admin password${tty_reset} ${tty_dim}when prompted to continue${tty_reset}."
  fi
  execute_sudo true
fi

if [[ "${BREW_NEEDS_INSTALL:-0}" == "1" ]]; then
  install_homebrew
fi

install_core_homebrew_packages
install_brewfiles
install_ssh_keys
install_dotpkgs
show_homebrew_shellenv_reminder

# FIN!
exit 0
