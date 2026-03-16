## {{ UNRELEASED_VERSION }} - [{{ UNRELEASED_DATE }}]({{ UNRELEASED_LINK }})

- Added a hidden `--check-core` mode that lets scripts verify Homebrew and Bootbox core dependencies by exit status without running the full bootstrap flow.
- Added debug output for `--check-core` so automation can tell whether Homebrew itself or one of the core packages is missing.
- Updated Leia example coverage to exercise the core check failure-and-repair path and to run through a temporary `bootbox` alias in CI while keeping `dist/bootbox.sh` as the only published artifact.

## v1.0.0-beta.2 - [March 15, 2026](https://github.com/tanaabased/bootbox/releases/tag/v1.0.0-beta.2)

- Moved `netlify.toml` into `/`
- Reorganized from locations to better comply with Tanaab based guidance on netscripts

## v1.0.0-beta.1 - [March 14, 2026](https://github.com/tanaabased/bootbox/releases/tag/v1.0.0-beta.1)

- Added a hosted `bootbox.sh` entrypoint for bootstrapping fresh macOS 26 or newer machines.
- Added automatic Homebrew installation plus support for applying one or more Brewfiles.
- Added dotpackage support for linking machine configuration into a target home directory.
- Added optional 1Password-backed SSH key installation for private key bootstrap flows.
- Added release-shaped `dist/` publishing, hosted metadata, and GitHub Actions example coverage.
