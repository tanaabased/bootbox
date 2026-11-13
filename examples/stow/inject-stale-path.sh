#!/bin/bash
set -euo pipefail

[[ -n "${CI:-}" && "$(uname -s)" == Linux ]]
mode="${1:-stale}"
scratch="${2:-${PWD}/.tmp}"
prefix="$(brew --prefix)"
stow_prefix="$(brew --prefix stow)"
stow_prefix="$(cd -P "${stow_prefix}" && pwd)"
stow_script="${stow_prefix}/bin/stow"
[[ -O "${prefix}" && -O "${stow_script}" ]]
mkdir -p "${scratch}"

if [[ "${mode}" == restore ]]; then
  chmod u+w "${stow_script}"
  cat "${scratch}/stow-original" > "${stow_script}"
  exit 0
fi
if [[ ! -f "${scratch}/stow-original" ]]; then
  cp "${stow_script}" "${scratch}/stow-original"
fi

old_perl=0.0.0-bootbox-test
interpreter="${prefix}/opt/perl/bin/perl"
case "${mode}" in
  stale) ;;
  current-perl) old_perl="$(basename "$(cd -P "$(brew --prefix perl)" && pwd)")" ;;
  other-perl) interpreter=/usr/bin/perl ;;
  unrelated)
    awk 'NR == 1 { print; print "BEGIN { die \"controlled unrelated Stow failure\\n\"; }"; next } { print }' \
      "${scratch}/stow-original" > "${scratch}/stow-broken"
    chmod u+w "${stow_script}"
    cat "${scratch}/stow-broken" > "${stow_script}"
    exit 0
    ;;
  *) echo "unknown Stow fault: ${mode}" >&2; exit 1 ;;
esac

# Replace the generated library path, retaining the real Stow program and Perl.
awk -v prefix="${prefix}" -v stow_prefix="${stow_prefix}" \
  -v interpreter="${interpreter}" -v old_perl="${old_perl}" '
  NR == 1 { print "#!" interpreter; next }
  /^use lib / {
    print "use lib \"" stow_prefix "/" prefix "/Cellar/perl/" old_perl "/lib/perl5/site_perl/0.0\";"
    replaced++
    next
  }
  { print }
  END { if (replaced != 1) exit 1 }
' "${scratch}/stow-original" > "${scratch}/stow-broken"
chmod u+w "${stow_script}"
cat "${scratch}/stow-broken" > "${stow_script}"
