# Legacy Example

This example covers transitional compatibility for the old `TANAAB_*` environment namespace. New
callers should use `BOOTBOX_*`; this legacy support is not the forward public contract and will be
removed in a future release.

## Setup

```bash
# should reset the example scratch directory
rm -rf .tmp && mkdir -p .tmp

# should have prepared bootbox on PATH
command -v bootbox >/dev/null
```

## Testing

```bash
# should keep legacy environment variables out of help output
if bootbox --help | grep -F 'TANAAB_'; then exit 1; fi

# should accept legacy list environment defaults
TANAAB_BREWFILE='Brewfile.legacy' TANAAB_BREWFILES='Brewfile.extra' bootbox --help | grep -F -- '--brewfile       installs brewfiles from local paths or URLs [default: Brewfile.legacy,Brewfile.extra]'
TANAAB_DOTPKG='dotpkgs/legacy' TANAAB_DOTPKGS='dotpkgs/extra' bootbox --help | grep -F -- "--dotpkg         stows dot packages into the current user's home [default: dotpkgs/legacy,dotpkgs/extra]"
TANAAB_SSH_KEY='vault/item' TANAAB_SSH_KEYS='vault/extra' bootbox --help | grep -F -- "--ssh-key        installs 1password ssh keys into the current user's .ssh as vault/item[:filename] [default: vault/item,vault/extra]"

# should accept legacy scalar environment defaults
TANAAB_FORCE=1 bootbox --help | grep -F -- '--force          forces supported overwrite operations [default: on]'
TANAAB_QUIET=1 bootbox --help | grep -F -- '--quiet          suppresses bootbox status output [default: on]'
TANAAB_DEBUG=1 bootbox --help | grep -F -- '--debug          shows debug messages [default: on]'

# should mask legacy token defaults in help
TANAAB_OP_TOKEN='legacy-token-5678' bootbox --help | grep -F 'lega...5678'
if TANAAB_OP_TOKEN='legacy-token-5678' bootbox --help | grep -F 'legacy-token-5678'; then exit 1; fi

# should prefer bootbox list environment defaults over legacy defaults
BOOTBOX_BREWFILE='Brewfile.preferred' TANAAB_BREWFILE='Brewfile.legacy' TANAAB_BREWFILES='Brewfile.extra' bootbox --help | grep -F -- '--brewfile       installs brewfiles from local paths or URLs [default: Brewfile.preferred]'
if BOOTBOX_BREWFILE='Brewfile.preferred' TANAAB_BREWFILE='Brewfile.legacy' TANAAB_BREWFILES='Brewfile.extra' bootbox --help | grep -F 'Brewfile.legacy'; then exit 1; fi

# should prefer bootbox token defaults over legacy token defaults
BOOTBOX_OP_TOKEN='preferred-token-1234' TANAAB_OP_TOKEN='legacy-token-5678' bootbox --help | grep -F 'pref...1234'
if BOOTBOX_OP_TOKEN='preferred-token-1234' TANAAB_OP_TOKEN='legacy-token-5678' bootbox --help | grep -F 'lega...5678'; then exit 1; fi

# should allow legacy debug to keep hidden core probe diagnostics on stderr
TANAAB_DEBUG=1 bootbox --check-core > .tmp/check-core-legacy.stdout 2> .tmp/check-core-legacy.stderr || test "$?" -eq 1
test ! -s .tmp/check-core-legacy.stdout
grep -F 'running hidden --check-core mode' .tmp/check-core-legacy.stderr

# should accept legacy platform override values
TANAAB_DEBUG=1 TANAAB_ARCH=arm64 TANAAB_OS=macos bootbox --check-core > .tmp/platform-legacy.stdout 2> .tmp/platform-legacy.stderr || test "$?" -eq 1
grep -F 'raw ARCH=arm64' .tmp/platform-legacy.stderr
grep -F 'raw OS=macos' .tmp/platform-legacy.stderr
```
