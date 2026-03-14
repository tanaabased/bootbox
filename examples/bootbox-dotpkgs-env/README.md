# Bootbox Dotpkgs Env Example

This example uses the `TANAAB_DOTPKG` and `TANAAB_TARGET` environment variables to stow multiple
dot packages into an example-local target directory.

## Setup

```bash
# should reset the example scratch directory
rm -rf .tmp && mkdir -p .tmp/home

# should stow the requested dotpkgs from environment variables
CI=1 NONINTERACTIVE=1 \
TANAAB_DOTPKG="dotpkgs/git,dotpkgs/vim" \
TANAAB_TARGET="$(pwd)/.tmp/home" \
bootbox.sh > .tmp/setup.log 2>&1
```

## Testing

```bash
# should symlink the git config into the target
test -L .tmp/home/.gitconfig

# should link the git config to the expected file contents
test "$(cat .tmp/home/.gitconfig)" = "$(cat dotpkgs/git/.gitconfig)"

# should install the git config contents
grep -F 'Bootbox Dotpkgs Env' .tmp/home/.gitconfig

# should symlink the vim config into the target
test -L .tmp/home/.vimrc

# should link the vim config to the expected file contents
test "$(cat .tmp/home/.vimrc)" = "$(cat dotpkgs/vim/.vimrc)"

# should install the vim config contents
grep -F 'BOOTBOX_DOTPKGS_ENV=1' .tmp/home/.vimrc
```

## Destroy tests

```bash
# should remove the example scratch directory
rm -rf .tmp
```
