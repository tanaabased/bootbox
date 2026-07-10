# SSH Keys Example

This example uses repeated `--ssh-key` options plus a CI-provided 1Password token to install the
same key twice: once by forcibly replacing an existing default filename and once with a filename
override. Input-source precedence is covered separately by the inputs example.

## Setup

```bash
# should prepare an existing ssh key destination
rm -rf .tmp && mkdir -p .tmp/home/.ssh
chmod 700 .tmp/home/.ssh
printf '%s\n' 'existing key material' > .tmp/home/.ssh/id_test
chmod 600 .tmp/home/.ssh/id_test

# should have the 1password test token available
test -n "$BOOTBOX_OP_TESTVAULT"

# should install the requested ssh keys from 1password
HOME="$(pwd)/.tmp/home" bootbox \
  --force \
  --ssh-key "omfsw2uztmi2xqpid5g3kiv6ba/id_test" \
  --ssh-key "omfsw2uztmi2xqpid5g3kiv6ba/id_test:id_test_bootbox" \
  --op-token "$BOOTBOX_OP_TESTVAULT" \
  > .tmp/setup.log 2>&1
```

## Testing

```bash
# should create the ssh directory
test -d .tmp/home/.ssh

# should protect the ssh directory permissions
test "$(find .tmp/home/.ssh -prune -perm 700 -print)" = ".tmp/home/.ssh"

# should install the default ssh key filename
test -f .tmp/home/.ssh/id_test

# should protect the default ssh key permissions
test "$(find .tmp/home/.ssh/id_test -prune -perm 600 -print)" = ".tmp/home/.ssh/id_test"

# should install the overridden ssh key filename
test -f .tmp/home/.ssh/id_test_bootbox

# should protect the overridden ssh key permissions
test "$(find .tmp/home/.ssh/id_test_bootbox -prune -perm 600 -print)" = ".tmp/home/.ssh/id_test_bootbox"

# should install the default ssh key material that matches the expected public key
test "$(ssh-keygen -y -f .tmp/home/.ssh/id_test | awk '{print $1 \" \" $2}')" = "$(awk '{print $1 \" \" $2}' id_test.pub)"

# should install the overridden ssh key material that matches the expected public key
test "$(ssh-keygen -y -f .tmp/home/.ssh/id_test_bootbox | awk '{print $1 \" \" $2}')" = "$(awk '{print $1 \" \" $2}' id_test.pub)"

# should log the forced overwrite
grep -F 'overwriting existing key' .tmp/setup.log
```
