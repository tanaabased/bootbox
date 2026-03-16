# Bootbox Brewfiles Env Example

This example uses `TANAAB_BREWFILE` and `TANAAB_DEBUG` to exercise multi-source Brewfile handling
with a local Brewfile and a `file://` Brewfile URL, then verifies the requested formulas are
available afterwards.

## Setup

```bash
# should reset the example scratch directory
rm -rf .tmp && mkdir -p .tmp/home

# should run bootbox with local and file-url brewfiles from environment variables
url_brewfile="file://$(pwd)/Brewfile.url" && \
CI=1 NONINTERACTIVE=1 \
TANAAB_BREWFILE="Brewfile.base,$url_brewfile" \
TANAAB_DEBUG=1 \
TANAAB_TARGET="$(pwd)/.tmp/home" \
bootbox > .tmp/setup.log 2>&1
```

## Testing

```bash
# should log the normalized local Brewfile path
grep -F "$(pwd)/Brewfile.base" .tmp/setup.log

# should log the file-url Brewfile source
url_brewfile="file://$(pwd)/Brewfile.url" && grep -F "$url_brewfile" .tmp/setup.log

# should fetch the file-url Brewfile through the URL path
url_brewfile="file://$(pwd)/Brewfile.url" && grep -F "fetching brewfile $url_brewfile" .tmp/setup.log

# should prepare an effective Brewfile from both sources
grep -F 'prepared effective brewfile at' .tmp/setup.log

# should enable debug logging from the environment
grep -F 'raw DEBUG=1' .tmp/setup.log

# should make the local Brewfile formula available
command -v watch >/dev/null || test -x /opt/homebrew/bin/watch || test -x /usr/local/bin/watch

# should make the file-url Brewfile formula available
command -v bats >/dev/null || test -x /opt/homebrew/bin/bats || test -x /usr/local/bin/bats
```

## Destroy tests

```bash
# should remove the example scratch directory
rm -rf .tmp
```
