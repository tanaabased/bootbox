# Bootbox SSH Keys Flags Example

This example uses repeated `--ssh-key` flags plus a CI-provided 1Password token to install the same
key twice: once with the default filename and once with a filename override.

## Setup

```bash
# should reset the example scratch directory
rm -rf .tmp && mkdir -p .tmp/home

# should have the 1password test token available
test -n "$TANAAB_OP_TESTVAULT"

# should install the requested ssh keys from 1password
CI=1 NONINTERACTIVE=1 \
bootbox \
  --target "$(pwd)/.tmp/home" \
  --ssh-key "omfsw2uztmi2xqpid5g3kiv6ba/id_test" \
  --ssh-key "omfsw2uztmi2xqpid5g3kiv6ba/id_test:id_test_bootbox" \
  --op-token "$TANAAB_OP_TESTVAULT" \
  > .tmp/setup.log 2>&1
```

## Testing

```bash
# should create the ssh directory
test -d .tmp/home/.ssh

# should protect the ssh directory permissions
test "$(stat -f '%Lp' .tmp/home/.ssh)" = "700"

# should install the default ssh key filename
test -f .tmp/home/.ssh/id_test

# should protect the default ssh key permissions
test "$(stat -f '%Lp' .tmp/home/.ssh/id_test)" = "600"

# should install the overridden ssh key filename
test -f .tmp/home/.ssh/id_test_bootbox

# should protect the overridden ssh key permissions
test "$(stat -f '%Lp' .tmp/home/.ssh/id_test_bootbox)" = "600"

# should install the default ssh key material that matches the expected public key
test "$(ssh-keygen -y -f .tmp/home/.ssh/id_test | awk '{print $1 \" \" $2}')" = "$(awk '{print $1 \" \" $2}' id_test.pub)"

# should install the overridden ssh key material that matches the expected public key
test "$(ssh-keygen -y -f .tmp/home/.ssh/id_test_bootbox | awk '{print $1 \" \" $2}')" = "$(awk '{print $1 \" \" $2}' id_test.pub)"
```

## Destroy tests

```bash
# should remove the example scratch directory
rm -rf .tmp
```
