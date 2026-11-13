#!/bin/bash
set -euo pipefail

[[ -n "${CI:-}" && "$(uname -s)" == Linux ]]
prefix="$(brew --prefix)"
stow_prefix="$(brew --prefix stow)"
stow_prefix="$(cd -P "${stow_prefix}" && pwd)"
stow_script="${stow_prefix}/bin/stow"
[[ -O "${prefix}" && -O "${stow_script}" ]]

# Replace the generated library path, retaining the real Stow program and Perl.
awk -v prefix="${prefix}" -v stow_prefix="${stow_prefix}" '
  NR == 1 { print "#!" prefix "/opt/perl/bin/perl"; next }
  /^use lib / {
    print "use lib \"" stow_prefix "/" prefix "/Cellar/perl/0.0.0-bootbox-test/lib/perl5/site_perl/0.0\";"
    replaced++
    next
  }
  { print }
  END { if (replaced != 1) exit 1 }
' "${stow_script}" > .tmp/stow-broken
chmod u+w "${stow_script}"
cat .tmp/stow-broken > "${stow_script}"
