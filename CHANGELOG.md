## {{ UNRELEASED_VERSION }} - [{{ UNRELEASED_DATE }}]({{ UNRELEASED_LINK }})

## v1.0.0-beta.7 - [July 9, 2026](https://github.com/tanaabased/bootbox/releases/tag/v1.0.0-beta.7)

- Added internal `BOOTBOX_EXTERNAL_SUDO` support for caller-managed sudo sessions. ([#9](https://github.com/tanaabased/bootbox/pull/9))

## v1.0.0-beta.6 - [June 17, 2026](https://github.com/tanaabased/bootbox/releases/tag/v1.0.0-beta.6)

- Added `--no-sudo` and `BOOTBOX_NO_SUDO` for no-elevation bootstrap flows. ([#6](https://github.com/tanaabased/bootbox/pull/6))
- Added `--quiet` and `BOOTBOX_QUIET` for wrapper-friendly status output suppression. ([#6](https://github.com/tanaabased/bootbox/pull/6))
- Changed the public environment variable namespace to `BOOTBOX_*`. ([#6](https://github.com/tanaabased/bootbox/pull/6))
- Tightened value-taking flag parsing for missing values and empty repeatable-list overrides. ([#6](https://github.com/tanaabased/bootbox/pull/6))

## v1.0.0-beta.5 - [May 2, 2026](https://github.com/tanaabased/bootbox/releases/tag/v1.0.0-beta.5)

- Updated `bootbox` core to install `1password-cli@beta` for 1Password Environment support. ([#5](https://github.com/tanaabased/bootbox/pull/5), [#4](https://github.com/tanaabased/bootbox/issues/4))

## v1.0.0-beta.4 - [March 18, 2026](https://github.com/tanaabased/bootbox/releases/tag/v1.0.0-beta.4)

- Fixed debug logging to mask 1Password service account tokens.
- Fixed `running` status labels to use the shared Tanaab action color.

## v1.0.0-beta.3 - [March 16, 2026](https://github.com/tanaabased/bootbox/releases/tag/v1.0.0-beta.3)

- Added a hidden `--check-core` mode that lets scripts verify core dependencies by exit status.
- Updated Leia example coverage invoke `bootbox` alias in CI while keeping `dist/bootbox.sh` as the only published artifact.

## v1.0.0-beta.2 - [March 15, 2026](https://github.com/tanaabased/bootbox/releases/tag/v1.0.0-beta.2)

- Moved `netlify.toml` into `/`
- Reorganized from locations to better comply with Tanaab based guidance on netscripts

## v1.0.0-beta.1 - [March 14, 2026](https://github.com/tanaabased/bootbox/releases/tag/v1.0.0-beta.1)

- Added a hosted `bootbox.sh` entrypoint for bootstrapping fresh macOS 26 or newer machines.
- Added automatic Homebrew installation plus support for applying one or more Brewfiles.
- Added dotpackage support for linking machine configuration into a target home directory.
- Added optional 1Password-backed SSH key installation for private key bootstrap flows.
- Added release-shaped `dist/` publishing, hosted metadata, and GitHub Actions example coverage.
