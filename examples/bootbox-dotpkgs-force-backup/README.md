# Bootbox Dotpkgs Force Backup Example

This example verifies that Bootbox backs up conflicting target files before stowing a replacement
when `TANAAB_FORCE=1` is set.

## Setup

```bash
# should reset the example scratch directory
rm -rf .tmp && mkdir -p .tmp/home

# should seed a conflicting target file
cat > .tmp/home/.gitconfig <<'EOF'
[user]
  name = Existing Local Git User
EOF

# should back up the conflicting file when force mode is enabled
CI=1 NONINTERACTIVE=1 \
TANAAB_DOTPKG="dotpkgs/git" \
TANAAB_FORCE=1 \
TANAAB_TARGET="$(pwd)/.tmp/home" \
bootbox > .tmp/setup.log 2>&1
```

## Testing

```bash
# should replace the conflicting git config with a symlink
test -L .tmp/home/.gitconfig

# should link the replacement git config to the expected file contents
test "$(cat .tmp/home/.gitconfig)" = "$(cat dotpkgs/git/.gitconfig)"

# should install the replacement git config contents
grep -F 'Bootbox Backup Example' .tmp/home/.gitconfig

# should create a backup copy of the conflicting file
find .tmp/home/.tanaab-backups -name '.gitconfig' | grep .

# should preserve the original git config in the backup copy
backup_file="$(find .tmp/home/.tanaab-backups -name '.gitconfig' | head -n 1)" && grep -F 'Existing Local Git User' "$backup_file"

# should log that conflicting files were backed up
grep -F 'backed up' .tmp/setup.log
```

## Destroy tests

```bash
# should remove the example scratch directory
rm -rf .tmp
```
