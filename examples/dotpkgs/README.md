# Dotpkgs Example

This example uses repeated `--dotpkg` options to stow multiple dot packages into an example-local
home directory. It also verifies that `bootbox` automatically backs up a conflicting home file before
stowing its replacement. Input-source precedence is covered separately by the inputs example.

## Setup

```bash
# should prepare clean and conflicting target state
rm -rf .tmp && mkdir -p .tmp/home
cat > .tmp/home/.gitconfig <<'EOF'
[user]
  name = Existing Local Git User
EOF

# should stow the requested dotpkgs
HOME="$(pwd)/.tmp/home" bootbox \
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
grep -F 'Bootbox Dotpkgs Example' .tmp/home/.gitconfig

# should symlink the zsh config into the target
test -L .tmp/home/.zshrc

# should link the zsh config to the expected file contents
test "$(cat .tmp/home/.zshrc)" = "$(cat dotpkgs/zsh/.zshrc)"

# should install the zsh config contents
grep -F 'BOOTBOX_DOTPKGS=1' .tmp/home/.zshrc

# should create a backup copy of the conflicting file
find .tmp/home/.tanaab-backups -name '.gitconfig' | grep .

# should preserve the original git config in the backup copy
backup_file="$(find .tmp/home/.tanaab-backups -name '.gitconfig' | head -n 1)" && grep -F 'Existing Local Git User' "$backup_file"

# should log that conflicting files were backed up
grep -F 'backed up' .tmp/setup.log
```
