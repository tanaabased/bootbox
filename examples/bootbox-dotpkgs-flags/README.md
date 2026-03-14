# Bootbox Dotpkgs Flags Example

This example uses repeated `--dotpkg` flags to stow multiple dot packages into an example-local
target directory.

## Setup

```bash
# should reset the example scratch directory
rm -rf .tmp && mkdir -p .tmp/home

# should stow the requested dotpkgs from CLI flags
CI=1 NONINTERACTIVE=1 \
bootbox.sh \
  --target "$(pwd)/.tmp/home" \
  --dotpkg dotpkgs/git \
  --dotpkg dotpkgs/zsh \
  > .tmp/setup.log 2>&1
```

## Testing

```bash
# should symlink the git config into the target
test -L .tmp/home/.gitconfig

# should link the git config to the expected file contents
test "$(cat .tmp/home/.gitconfig)" = "$(cat dotpkgs/git/.gitconfig)"

# should install the git config contents
grep -F 'Bootbox Dotpkgs Flags' .tmp/home/.gitconfig

# should symlink the zsh config into the target
test -L .tmp/home/.zshrc

# should link the zsh config to the expected file contents
test "$(cat .tmp/home/.zshrc)" = "$(cat dotpkgs/zsh/.zshrc)"

# should install the zsh config contents
grep -F 'BOOTBOX_DOTPKGS_FLAGS=1' .tmp/home/.zshrc
```

## Destroy tests

```bash
# should remove the example scratch directory
rm -rf .tmp
```
