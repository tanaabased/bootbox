#!/bin/bash
set -euo pipefail

[[ -n "${CI:-}" && "$(uname -s)" == Linux ]]
script_dir="$(cd "$(dirname "$0")" && pwd)"
prefix="$(brew --prefix)"
[[ -O "${prefix}" && -L "${prefix}/bin/brew" ]]
real_brew="$(readlink -f "${prefix}/bin/brew")"
[[ -x "${real_brew}" && "${real_brew}" != "${prefix}/bin/brew" ]]
control="${prefix}/.bootbox-stow-test"
mkdir "${control}"
printf '%s\n' "${real_brew}" > "${control}/real-brew"
printf '%s\n' "${script_dir}/inject-stale-path.sh" > "${control}/injector"
: > "${control}/mode"
rm "${prefix}/bin/brew"
cp "${script_dir}/brew" "${prefix}/bin/brew"
chmod +x "${prefix}/bin/brew"
