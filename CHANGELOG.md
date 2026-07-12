## {{ UNRELEASED_VERSION }} - [{{ UNRELEASED_DATE }}]({{ UNRELEASED_LINK }})

### New Features

- Added 64-bit Linux support on `x64` and `arm64` with canonical Linuxbrew prefix detection. ([#11](https://github.com/tanaabased/bootbox/pull/11))
- Added a current-user execution model that keeps Brewfiles, SSH keys, and dotpackages sudo-free. ([#11](https://github.com/tanaabased/bootbox/pull/11))
- Added conditional shell setup reminders after fresh Homebrew installs without editing startup files. ([#11](https://github.com/tanaabased/bootbox/pull/11))
- Added distribution-neutral Linux checks for Git 2.7+, glibc 2.13+, a compiler, `make`, `file`, and `ps`. ([#11](https://github.com/tanaabased/bootbox/pull/11))

### Breaking Changes

- Removed `--target`, `BOOTBOX_TARGET`, and legacy target overrides; user files now always use `$HOME`. ([#11](https://github.com/tanaabased/bootbox/pull/11))
- Removed internal `BOOTBOX_EXTERNAL_SUDO`; `NONINTERACTIVE` and `CI` now reuse sudo without prompting. ([#11](https://github.com/tanaabased/bootbox/pull/11))
- Required existing Homebrew installations to be user-manageable; bootbox no longer repairs them with sudo. ([#11](https://github.com/tanaabased/bootbox/pull/11))

### Bug Fixes

- Fixed `--check-core` to report unready when Homebrew exists but is not manageable by the current user. ([#11](https://github.com/tanaabased/bootbox/pull/11))
- Fixed fresh Linux Homebrew installs to skip `/snap/bin/curl` when another compatible cURL is available. ([#11](https://github.com/tanaabased/bootbox/pull/11))
- Fixed interactive pipe-to-Bash confirmations to read from `/dev/tty` when available. ([#11](https://github.com/tanaabased/bootbox/pull/11))
- Fixed invalid `INTERACTIVE`, `NONINTERACTIVE`, and `CI` combinations to fail before mutation. ([#11](https://github.com/tanaabased/bootbox/pull/11))
- Fixed noninteractive sudo authorization to use `sudo -n` and fail instead of prompting. ([#11](https://github.com/tanaabased/bootbox/pull/11))
- Fixed ownership and permission validation for `$HOME`, SSH destinations, and dotpackage conflicts. ([#11](https://github.com/tanaabased/bootbox/pull/11))

### Developer Notes

- Expanded Leia contract coverage across macOS 26 and Ubuntu 24.04, including fresh Homebrew installs. ([#11](https://github.com/tanaabased/bootbox/pull/11))

## v1.0.0-beta.8 - [July 10, 2026](https://github.com/tanaabased/bootbox/releases/tag/v1.0.0-beta.8)

- Fixed `sudo` credential checks so they only run when planned operations require elevated file helpers.

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
