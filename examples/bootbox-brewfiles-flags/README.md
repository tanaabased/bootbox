# Bootbox Brewfiles Flags Example

This example uses repeated `--brewfile` flags with a local Brewfile and a `file://` Brewfile URL to
exercise multi-source Brewfile handling under `--debug` and verify the requested formulas are
available afterwards.

## Setup

```bash
# should reset the example scratch directory
rm -rf .tmp && mkdir -p .tmp/home

# should run bootbox with local and file-url brewfiles from CLI flags
url_brewfile="file://$(pwd)/Brewfile.url" && \
CI=1 NONINTERACTIVE=1 \
bootbox.sh \
  --target "$(pwd)/.tmp/home" \
  --debug \
  --brewfile Brewfile.base \
  --brewfile "$url_brewfile" \
  > .tmp/setup.log 2>&1
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

# should enable debug logging
grep -F 'raw DEBUG=1' .tmp/setup.log

# should make the local Brewfile formula available
command -v tree >/dev/null || test -x /opt/homebrew/bin/tree || test -x /usr/local/bin/tree

# should make the file-url Brewfile formula available
command -v pv >/dev/null || test -x /opt/homebrew/bin/pv || test -x /usr/local/bin/pv
```

## Destroy tests

```bash
# should remove the example scratch directory
rm -rf .tmp
```
