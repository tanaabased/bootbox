# bootbox

`bootbox` is a hosted bootstrap script for macOS and Linux that turns a fresh box into a usable base
machine for the current user. It installs Homebrew, applies one or more Brewfiles, stows one or more
dotpackages into the current user's home, and can install private SSH keys from a 1Password vault.

> Supports macOS 26 or higher and 64-bit Linux on `x64` and `arm64`. CI covers Ubuntu 24.04.

## Quickstart

```sh
curl -fsSL https://bootbox.tanaab.sh/bootbox.sh | bash
```

## Installation

`bootbox` is designed to be run directly from the hosted script at
`https://bootbox.tanaab.sh/bootbox.sh`.

- It requires Bash and cURL 7.41 or newer to start. Homebrew cannot use cURL installed through
  Snap, so Linux systems must provide a non-Snap cURL.
- It configures only the invoking user's `$HOME`.
- The normal setup assumes the invoking user can use admin or sudo access if Homebrew must be
  installed.
- When Homebrew is missing, sudo 1.9.12 or newer is required unless `--no-sudo` is used to hand
  installation responsibility to another machine-prep layer.
- `bootbox` does not edit shell startup files. After installing Homebrew, it prints a shell setup
  reminder only when Homebrew's `bin` directory was not already in `PATH` and the relevant startup
  file does not already contain the required `brew shellenv` line.
- Before installing missing Homebrew on Linux, it requires Git 2.7 or newer, glibc 2.13 or newer, a
  C compiler (`cc`, `gcc`, or `clang`), `make`, `file`, and `ps`. Install the equivalent system
  dependencies for your distribution first; `bootbox` does not invoke a distro package manager.
- An existing Homebrew installation must be manageable by the invoking user without sudo.
- For 1Password-backed SSH keys, provide a service account token with `--op-token`,
  `BOOTBOX_OP_TOKEN`, or `OP_SERVICE_ACCOUNT_TOKEN`.
- `bootbox` currently installs the beta 1Password CLI cask for Environment commands such as
  `op run --environment`. This should return to stable `1password-cli` once stable 1Password CLI
  includes that support.
- The hosted URL serves the generated `dist/bootbox.sh` entrypoint used for releases.

## User And Homebrew Model

`bootbox` is designed around one Homebrew-managing user. It may use sudo to install Homebrew into
the platform's supported prefix, but Homebrew commands and all user configuration run without sudo.
Existing Homebrew access may come from direct ownership or trusted group permissions; `bootbox`
checks effective access rather than requiring one specific owner.

SSH keys and dotpackages are always installed relative to the invoking user's `$HOME`. `bootbox`
does not configure another user's home and does not elevate file operations to work around home
directory permissions.

## Usage

The main flow is: choose a target machine, decide which Brewfiles and dotpackages you want, and then
run `bootbox` once to converge the box into that state. If you have installed the hosted script as a
local `bootbox` command, the common flows look like this:

```sh
bootbox --brewfile Brewfile.work
bootbox --dotpkg dotpkgs/git --dotpkg dotpkgs/zsh
bootbox --ssh-key "my-vault/id_work" --op-token "$BOOTBOX_OP_TOKEN"
```

If you are working from a local checkout instead, replace `bootbox` with `./bootbox.sh`.

The `examples/` directory contains Leia-backed scenario folders for the main supported flows,
including multi-Brewfile installs, dotpackage installs, and live 1Password SSH key installation.

## Configuration

`bootbox` keeps its configuration surface intentionally small.

- `BOOTBOX_BREWFILE`: comma-separated Brewfile paths or URLs
- `BOOTBOX_DOTPKG`: comma-separated dotpackage paths
- `BOOTBOX_SSH_KEY`: comma-separated `vault/item[:filename]` SSH key specs
- `BOOTBOX_OP_TOKEN`: 1Password service account token
- `BOOTBOX_FORCE`: enables supported overwrite behavior
- `BOOTBOX_QUIET`: suppresses `bootbox` status output for wrapper callers
- `BOOTBOX_NO_SUDO`: disables sudo checks, prompts, and elevation
- `BOOTBOX_DEBUG`: enables debug logging
- `NONINTERACTIVE` and `CI`: disable prompts for automated runs

## Advanced

If you want a reusable local command instead of piping the hosted script every time, install it into
a directory that is already in your `PATH` or one you manage yourself.

```sh
mkdir -p "$HOME/.local/bin"
curl -fsSL https://bootbox.tanaab.sh/bootbox.sh -o "$HOME/.local/bin/bootbox"
chmod +x "$HOME/.local/bin/bootbox"

bootbox --help
bootbox --brewfile Brewfile.work --dotpkg dotpkgs/git
bootbox --ssh-key "my-vault/id_work:id_ed25519_work" --op-token "$BOOTBOX_OP_TOKEN"
```

If you do not want to install a local command first, you can also set environment variables inline
and pipe the hosted script straight into Bash.

```sh
curl -fsSL https://bootbox.tanaab.sh/bootbox.sh | BOOTBOX_BREWFILE="Brewfile.work" bash
curl -fsSL https://bootbox.tanaab.sh/bootbox.sh | BOOTBOX_DOTPKG="dotpkgs/git,dotpkgs/zsh" bash
curl -fsSL https://bootbox.tanaab.sh/bootbox.sh | BOOTBOX_SSH_KEY="my-vault/id_work:id_work" BOOTBOX_OP_TOKEN="$BOOTBOX_OP_TOKEN" bash
```

For the complete and current documented CLI surface, prefer `--help`. That output is the fastest
source of truth for supported public flags, environment variables, and guardrails.

For scripts that only need to know whether `bootbox`'s built-in Homebrew base is already satisfied,
there is also a hidden `--check-core` flag. It exits `0` when Homebrew plus `bootbox`'s core
packages are already installed, and exits `1` otherwise. It intentionally stays out of `--help`,
and it does not check Brewfile entries, dotpackages, SSH keys, or home-directory permissions.

```sh
if bootbox --check-core >/dev/null 2>&1; then
  echo "bootbox core is ready"
else
  echo "bootbox core is missing dependencies"
fi
```

Wrapper scripts that already know sudo is unavailable can pass `--no-sudo` or
`BOOTBOX_NO_SUDO=1`. In that mode `bootbox` does not probe, prompt for, or invoke sudo; requested
work must already be writable by the current user.

### Shared Homebrew Access

Homebrew documents shared multi-user installations as unsupported. If you intentionally maintain
one anyway, prepare it outside `bootbox` and limit membership to users who fully trust one another:
every member with write access can replace executables used by the other members. See the
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

## Development

`bootbox` uses Bun for its repo-local tooling and publishes a Netlify-ready `dist/` directory.

```sh
bun install
bun run lint
bun run build
```

The example suite is intentionally not exposed as a local package script. Leia examples are run in
GitHub Actions on fresh macOS and Ubuntu runners because they can mutate machine state, install
Homebrew packages, and access the `BOOTBOX_OP_TESTVAULT` CI environment value for the live SSH-key
example.

## Issues, Questions and Support

Use the [GitHub issue queue](https://github.com/tanaabased/bootbox/issues) for bugs, regressions,
or feature requests.

## Changelog

See [`CHANGELOG.md`](./CHANGELOG.md) for release history and
[GitHub releases](https://github.com/tanaabased/bootbox/releases) for published artifacts.

## Maintainers

- `@pirog`

## Contributors

<a href="https://github.com/tanaabased/bootbox/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=tanaabased/bootbox" />
</a>

Made with [contrib.rocks](https://contrib.rocks).
