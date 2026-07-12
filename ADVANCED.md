# Advanced

This reference covers the complete public `bootbox` configuration surface, installed components,
platform requirements, current-user and Homebrew access rules, and wrapper-oriented execution
behavior. Start with [README.md](./README.md) for the primary bootstrap path.

## What Gets Installed

### Homebrew Core

When Homebrew is missing, `bootbox` installs it into the platform's canonical prefix:

- `/opt/homebrew` on Apple silicon macOS
- `/usr/local` on Intel macOS
- `/home/linuxbrew/.linuxbrew` on Linux

`bootbox` then makes sure these core packages are present:

- Git
- cURL
- Zsh
- jq
- GNU Stow
- `1password-cli@beta`

The beta 1Password CLI is used because 1Password Environment commands required by downstream
machine profiles are not yet available in the stable CLI contract used by this repository.

### Brewfiles

`bootbox` applies each selected Brewfile through Homebrew Bundle. Inputs may be local paths or
URLs, and more than one Brewfile can be selected in one run.

If no Brewfile input is provided and `./Brewfile` exists in the invocation directory, that file
becomes the implicit default. Use `--brewfile=` to clear an environment-sourced or implicit list.

### Dotpackages

Each selected dotpackage is applied to `$HOME` with GNU Stow. A dotpackage path names a package
directory whose parent becomes Stow's package directory.

Before stowing, `bootbox` simulates the operation and identifies conflicting targets. Existing
conflicts are preserved under `$HOME/.tanaab-backups/stow-<timestamp>/` before the requested
package is applied. Dotpackage files, backups, and conflict handling never use sudo.

### SSH Keys

SSH-key inputs use `vault/item[:filename]` syntax. `bootbox` reads each private key through the
1Password CLI and installs it under `$HOME/.ssh`.

The `.ssh` directory is set to mode `0700`, and installed private keys are set to mode `0600`.
The 1Password item name becomes the destination filename unless an explicit filename is supplied
after the colon.

Existing key destinations fail safely unless `--force` is set. Tokens remain masked in help,
planning, debug, and failure output.

## Platform And Execution Model

### macOS

`bootbox` supports macOS 26 or newer on `x64` and `arm64`. A missing Homebrew installation
requires `/usr/bin/sudo`; `bootbox` shows its plan before authorizing sudo in an interactive run.

### Linux

`bootbox` supports 64-bit Linux on `x64` and `arm64`. CI exercises Ubuntu 24.04, while other
distributions remain supported through capability checks rather than package-manager-specific
setup.

Before installing missing Homebrew, Linux must provide:

- Bash
- cURL 7.41 or newer from outside Snap
- Git 2.7 or newer
- glibc 2.13 or newer
- a C compiler through `cc`, `gcc`, or `clang`
- `make`
- `file`
- `ps`
- `/usr/bin/sudo`

`bootbox` reports missing capabilities before confirmation or sudo authorization. It does not
invoke `apt`, `dnf`, `yum`, `pacman`, or another distribution package manager. Homebrew owns
portable Ruby selection and optional Bubblewrap sandbox behavior.

When more than one cURL is available, `bootbox` skips `/snap/bin/curl` and selects another
compatible executable.

### Current User And Homebrew Access

`bootbox` configures only the invoking user's `$HOME`. SSH keys, dotpackages, conflict backups,
and home-directory permissions never use sudo, and there is no public target-home override.

An existing Homebrew installation must already be readable, writable, and traversable by the
invoking user across its managed prefix paths. Access may come from direct ownership or a trusted
shared group. `bootbox` does not use sudo to repair or take ownership of an existing installation.

### Interactive, CI, And Sudo Behavior

Interactive runs show the complete planned action list before the first sudo prompt. Hosted
pipe-to-Bash runs read confirmation through `/dev/tty` when it is available.

`NONINTERACTIVE`, `CI`, and `--yes` disable confirmation prompts. When Homebrew is missing,
noninteractive authorization uses `sudo -n` and fails rather than prompting when reusable sudo is
not available.

`--no-sudo` is stricter than noninteractive mode: it prevents sudo probes, prompts, timestamp
cleanup, and elevation. A missing Homebrew installation therefore fails immediately under
`--no-sudo`.

When Homebrew already exists and is manageable, Brewfiles, SSH keys, and dotpackages do not inspect
or invoke sudo.

### Shell Setup

`bootbox` never edits shell startup files directly. After a fresh Homebrew installation, it prints
a shell setup reminder only when Homebrew was absent from the inherited `PATH` and the relevant
startup file does not already contain the expected `brew shellenv` command.

The suggested startup file follows Homebrew's platform and shell choices:

- `.bashrc` on Linux or `.bash_profile` on macOS for Bash
- `.zshrc` on Linux or `.zprofile` on macOS for Zsh
- `.config/fish/config.fish` for Fish
- `$ENV` or `.profile` as the fallback

## Configuration Reference

CLI options override environment variables, which override defaults. Run the hosted help for the
exact current contract:

```sh
/bin/bash -c "$(curl -fsSL https://bootbox.tanaab.sh/bootbox.sh)" bootbox --help
```

For repeatable inputs, the first CLI occurrence replaces the complete environment-sourced list.
Later occurrences append. Empty inline values such as `--brewfile=`, `--dotpkg=`, or
`--ssh-key=` intentionally clear the corresponding list.

### `--brewfile`

| Field       | Value                                                                          |
| ----------- | ------------------------------------------------------------------------------ |
| Environment | `BOOTBOX_BREWFILE`                                                             |
| Default     | `./Brewfile` when present in the invocation directory; otherwise none          |
| Values      | Repeatable local path or URL, or comma-separated environment-variable list     |
| Description | Applies Homebrew Bundle inputs after the built-in `bootbox` core is available. |

```sh
bootbox --brewfile Brewfile.base --brewfile https://example.com/Brewfile
```

### `--dotpkg`

| Field       | Value                                                                |
| ----------- | -------------------------------------------------------------------- |
| Environment | `BOOTBOX_DOTPKG`                                                     |
| Default     | none                                                                 |
| Values      | Repeatable package path or comma-separated environment-variable list |
| Description | Applies GNU Stow packages to the invoking user's `$HOME`.            |

```sh
bootbox --dotpkg dotpkgs/git --dotpkg dotpkgs/zsh
```

Conflicting targets are backed up automatically before stowing.

### `--ssh-key`

| Field       | Value                                                                        |
| ----------- | ---------------------------------------------------------------------------- |
| Environment | `BOOTBOX_SSH_KEY`                                                            |
| Default     | none                                                                         |
| Values      | Repeatable `vault/item[:filename]` value or comma-separated environment list |
| Description | Installs private SSH keys from 1Password into `$HOME/.ssh`.                  |

```sh
bootbox \
  --ssh-key "my-vault/id_work" \
  --ssh-key "my-vault/id_agent:id_ed25519_agent" \
  --op-token "$BOOTBOX_OP_TOKEN"
```

### `--op-token`

| Field       | Value                                                        |
| ----------- | ------------------------------------------------------------ |
| Environment | `BOOTBOX_OP_TOKEN`; falls back to `OP_SERVICE_ACCOUNT_TOKEN` |
| Default     | unset                                                        |
| Values      | 1Password service account token                              |
| Description | Authenticates private SSH-key retrieval from 1Password.      |

The token is required when the SSH-key list is non-empty. Prefer an environment variable when
keeping the value out of shell history matters:

```sh
BOOTBOX_OP_TOKEN="$OP_TOKEN" bootbox --ssh-key "my-vault/id_work"
```

### `-y`, `--yes`

| Field       | Value                                      |
| ----------- | ------------------------------------------ |
| Environment | `NONINTERACTIVE`                           |
| Default     | unset                                      |
| Values      | Flag or truthy environment value           |
| Description | Accepts the plan and runs without prompts. |

```sh
bootbox --yes
```

### `--force`

| Field       | Value                                             |
| ----------- | ------------------------------------------------- |
| Environment | `BOOTBOX_FORCE`                                   |
| Default     | off                                               |
| Values      | Flag or truthy environment value                  |
| Description | Allows supported existing targets to be replaced. |

`--force` permits an existing SSH-key destination to be overwritten. It does not make
current-user operations eligible for sudo, repair Homebrew ownership, or replace an invalid home
directory.

### `--quiet`

| Field       | Value                                      |
| ----------- | ------------------------------------------ |
| Environment | `BOOTBOX_QUIET`                            |
| Default     | off                                        |
| Values      | Flag or truthy environment value           |
| Description | Suppresses normal `bootbox` status output. |

Quiet mode is intended for wrapper callers. Debug output and failures remain visible on stderr.
It also suppresses the final `bootbox setup succeeded` status message.

### `--no-sudo`

| Field       | Value                                                   |
| ----------- | ------------------------------------------------------- |
| Environment | `BOOTBOX_NO_SUDO`                                       |
| Default     | off                                                     |
| Values      | Flag or truthy environment value                        |
| Description | Disables sudo probes, prompts, timestamp work, and use. |

Use this when a wrapper or machine-preparation layer owns Homebrew installation:

```sh
bootbox --no-sudo --brewfile Brewfile.work
```

Homebrew must already exist and be manageable by the invoking user.

### `--debug`

| Field       | Value                                  |
| ----------- | -------------------------------------- |
| Environment | `BOOTBOX_DEBUG`                        |
| Default     | off                                    |
| Values      | Flag or truthy environment value       |
| Description | Shows detailed diagnostic information. |

Debug output masks the 1Password token and does not log raw arguments.

### `--version`

Prints the running script version and exits:

```sh
bootbox --version
```

### `-h`, `--help`

Prints the current public CLI and environment-variable contract and exits:

```sh
bootbox --help
```

### `CI`

| Field       | Value                                 |
| ----------- | ------------------------------------- |
| Option      | none                                  |
| Default     | unset                                 |
| Values      | Truthy environment value              |
| Description | Runs in CI mode and disables prompts. |

## Shared Homebrew Access

Homebrew documents shared multi-user installations as unsupported. If you intentionally maintain
one anyway, prepare it outside `bootbox` and limit membership to users who fully trust one another:
every member with write access can replace executables used by the other members. Review the
[Homebrew FAQ](https://docs.brew.sh/FAQ) and
[support tiers](https://docs.brew.sh/Support-Tiers) before choosing this model.

A common manual pattern uses a dedicated `brewer` group, explicit trusted members, and group
read/write/traverse access throughout the Homebrew prefix. On macOS, an administrator can prepare
that pattern with:

```sh
brew_prefix="$(brew --prefix)"
sudo dseditgroup -o create brewer
sudo dseditgroup -o edit -a "$USER" -t user brewer
sudo find -x "$brew_prefix" -exec chgrp -h brewer {} +
sudo find -x "$brew_prefix" ! -type l -exec chmod g+rwX {} +
```

On Linux, the equivalent direct-membership setup is:

```sh
brew_prefix="$(brew --prefix)"
sudo groupadd --force brewer
sudo usermod --append --groups brewer "$USER"
sudo find "$brew_prefix" -xdev -exec chgrp --no-dereference brewer {} +
sudo find "$brew_prefix" -xdev ! -type l -exec chmod g+rwX {} +
sudo find "$brew_prefix" -xdev -type d -exec chmod g+s {} +
```

Add each additional trusted user directly to `brewer`, then start a new login session so group
membership is refreshed. `bootbox` will use an existing shared setup when the invoking user has
effective access, but it will not create groups or repair Homebrew permissions with sudo.
