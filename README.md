# Bootbox

Bootbox is a hosted bootstrap script for macOS 26 or newer that turns a fresh box into a usable
base machine. It installs Homebrew, applies one or more Brewfiles, stows one or more dotpackages,
and can install private SSH keys from a 1Password vault.

Bootbox is meant to be a reusable base script that narrower machine profiles can wrap and extend.
Examples of that pattern include [pirog/me](https://github.com/pirog/me),
[tanaabased/agentbox](https://github.com/tanaabased/agentbox), and
[tanaabased/emori](https://github.com/tanaabased/emori).

> Supports macOS 26 or higher on `x64` and `arm64`.

## Quickstart

```sh
curl -fsSL https://bootbox.tanaab.sh | bash
```

## Installation

Bootbox is designed to be run directly from the hosted script at `https://bootbox.tanaab.sh`.

- It requires Bash and cURL to start.
- It supports installing into the default home directory target or a custom `--target`.
- For 1Password-backed SSH keys, provide a service account token with `--op-token`,
  `TANAAB_OP_TOKEN`, or `OP_SERVICE_ACCOUNT_TOKEN`.
- The hosted URL serves the generated `dist/bootbox.sh` entrypoint used for releases.

## Usage

The main flow is: choose a target machine, decide which Brewfiles and dotpackages you want, and then
run Bootbox once to converge the box into that state. If you have installed the hosted script as a
local `bootbox` command, the common flows look like this:

```sh
bootbox --brewfile Brewfile.work --target "$HOME"
bootbox --dotpkg dotpkgs/git --dotpkg dotpkgs/zsh --target "$HOME"
bootbox --ssh-key "my-vault/id_work" --op-token "$TANAAB_OP_TOKEN"
```

If you are working from a local checkout instead, replace `bootbox` with `./bootbox.sh`.

The `examples/` directory contains Leia-backed scenario folders for the main supported flows,
including multi-Brewfile installs, dotpackage installs, and live 1Password SSH key installation.

## Configuration

Bootbox keeps its configuration surface intentionally small.

- `TANAAB_BREWFILE`: comma-separated Brewfile paths or URLs
- `TANAAB_DOTPKG`: comma-separated dotpackage paths
- `TANAAB_SSH_KEY`: comma-separated `vault/item[:filename]` SSH key specs
- `TANAAB_OP_TOKEN`: 1Password service account token
- `TANAAB_TARGET`: install target directory
- `TANAAB_FORCE`: enables supported overwrite behavior
- `TANAAB_DEBUG`: enables debug logging
- `NONINTERACTIVE` and `CI`: disable prompts for automated runs

## Advanced

If you want a reusable local command instead of piping the hosted script every time, install it into
a directory that is already in your `PATH` or one you manage yourself.

```sh
mkdir -p "$HOME/.local/bin"
curl -fsSL https://bootbox.tanaab.sh -o "$HOME/.local/bin/bootbox"
chmod +x "$HOME/.local/bin/bootbox"

bootbox --help
bootbox --brewfile Brewfile.work --dotpkg dotpkgs/git --target "$HOME"
bootbox --ssh-key "my-vault/id_work:id_ed25519_work" --op-token "$TANAAB_OP_TOKEN"
```

If you do not want to install a local command first, you can also set environment variables inline
and pipe the hosted script straight into Bash.

```sh
curl -fsSL https://bootbox.tanaab.sh | TANAAB_BREWFILE="Brewfile.work" TANAAB_TARGET="$HOME" bash
curl -fsSL https://bootbox.tanaab.sh | TANAAB_DOTPKG="dotpkgs/git,dotpkgs/zsh" TANAAB_TARGET="$HOME" bash
curl -fsSL https://bootbox.tanaab.sh | TANAAB_SSH_KEY="my-vault/id_work:id_work" TANAAB_OP_TOKEN="$TANAAB_OP_TOKEN" bash
```

For the complete and current CLI surface, prefer `--help`. That output is the fastest source of
truth for supported flags, environment variables, and guardrails.

## Development

Bootbox uses Bun for its repo-local tooling and publishes a Netlify-ready `dist/` directory.

```sh
bun install
bun run lint
bun run build
```

The example suite is intentionally not exposed as a local package script. Leia examples are run in
GitHub Actions on fresh macOS runners because they can mutate machine state, install Homebrew
packages, and access the `TANAAB_OP_TESTVAULT` CI secret for the live SSH-key example.

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
