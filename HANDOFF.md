# bootbox PR #11 handoff

This document captures the implementation and decision context for continuing the current `bootbox`
work from another machine or Codex instance.

## Repository state

- Repository: `tanaabased/bootbox`
- Pull request: [#11: refine sudo handling and leia coverage](https://github.com/tanaabased/bootbox/pull/11)
- Branch: `pirog-refine-sudo-and-leia`
- Base: `main`
- The pull request is currently a draft.
- Do not edit or regenerate `dist/`; CI and release workflows own generated distribution artifacts.

## Current direction

`bootbox` is now a current-user bootstrap for macOS and Linux. It installs or uses Homebrew, applies
Brewfiles, stows current-user dotpackages, and installs 1Password-backed SSH keys. Its supported
model is intentionally narrow:

- SSH keys and dotpackages always target the invoking user's `$HOME`.
- Only a missing Homebrew installation may require sudo.
- Existing Homebrew must already be manageable by the invoking user through ownership or trusted
  group access.
- `--no-sudo` is strict: no sudo probes, prompts, timestamp changes, or elevation.
- Linux prerequisite checks are capability-based and distribution-neutral; `bootbox` does not use a
  distro package manager.
- Multi-user Homebrew groups are documented as manual, advanced, upstream-unsupported setup.

## Work completed on PR #11

### Example organization and input coverage

- Consolidated separate environment-variable and flag scenarios into broader option-driven
  examples after expanding `examples/inputs` to cover defaults, environment variables, CLI
  overrides, repeatable values, and clearing behavior.
- Renamed broad example buckets to `homebrew`, `legacy`, `sudo`, and `ssh-keys`.
- Consolidated Brewfile, dotpackage, and force behavior into their corresponding examples.
- Expanded the defaults example to exercise the default core while passing only genuinely required
  inputs.
- Removed explicit `CI` and noninteractive setup from examples where GitHub Actions already supplies
  the runner context.

### macOS and Linux coverage

- Added a workflow matrix for `macos-26` and pinned `ubuntu-24.04`.
- Added `/home/linuxbrew/.linuxbrew/bin` to the workflow PATH on both platforms so workflow commands
  remain uniform.
- Added Linux OS and architecture detection and canonical Linuxbrew prefix handling.
- Verified the entire example matrix on both operating systems at commit `c28fa99`; all lint,
  release, macOS, Ubuntu, and Netlify checks were green at that head.

### Interactive and sudo handling

- Adopted the same `/dev/tty` input strategy used in `me` and `agentbox` so pipe-to-Bash invocations
  can still confirm interactively.
- Forwarded `CI` into cross-user sudo examples and fixed early interactive error rendering.
- Preserved pre-existing sudo credentials and limited external-sudo mode to an already-active
  credential.
- Kept sudo planning limited to missing Homebrew; Brewfiles, SSH keys, and dotpackages never elevate.
- Fixed cross-platform sudo example permissions and accessible working-directory behavior.

### Current-user model

- Removed the public target override and made `$HOME` the only SSH-key and dotpackage destination.
- Added early ownership validation for the invoking user's home.
- Added clear failures for inaccessible existing Homebrew and documented manual trusted-group setup.
- Confirmed that `bootbox` does not directly edit shell startup files. An explicitly requested
  dotpackage may still stow a file such as `.zshrc`, which is intentional user-owned behavior.

### Linux Homebrew installation

- Added a real `homebrew` example that moves the runner's canonical Homebrew prefix aside and uses
  `bootbox` to reinstall Homebrew on both macOS and Ubuntu.
- Added missing-Homebrew Linux prerequisite checks for Git 2.7+, glibc 2.13+, a C compiler, `make`,
  `file`, and `ps`.
- Removed Bubblewrap from the hard prerequisite list. Homebrew owns its optional sandbox validation
  and can install without `bwrap`.
- Confirmed the beta 1Password CLI cask provides Linux x64 and arm64 artifacts.
- Made SSH permission assertions portable by replacing BSD/GNU-specific `stat` usage.

## Latest compatibility follow-up

The latest change set was produced by a deeper portability audit after the macOS and Ubuntu matrix
turned green:

- Reject `/snap/bin/curl`, matching the official Homebrew installer's behavior, while allowing
  `find_tool` to choose another compatible curl.
- Require sudo 1.9.12 or newer only when missing Homebrew needs elevation. This is the first sudo
  version supporting the `-N` credential check used by `bootbox`; Ubuntu 22.04's stock sudo 1.9.9 is
  intentionally outside this narrowed support boundary, while Ubuntu 24.04 satisfies it.
- Capture the inherited PATH before `brew shellenv` changes the current process.
- After a fresh Homebrew install, print a final shell-setup reminder only when `brew` is unavailable
  through that inherited PATH and the relevant startup file does not already contain the expected
  `brew shellenv` line.
- Mirror Homebrew's startup-file selection: `.bashrc` or `.zshrc` on Linux, `.bash_profile` or
  `.zprofile` on macOS, Fish's `config.fish`, and `.profile` as the fallback.
- Never modify those startup files automatically.
- Extend `examples/homebrew` to exercise Snap-curl fallback and the conditional final reminder.

## Validation status

- `bun run lint` passes for the latest source, README, and example changes.
- `git diff --check` passes.
- No local `dist/` build or Leia execution was performed; repository policy leaves generated output
  and runner-mutating examples to CI.
- The last remote head before this follow-up, `c28fa99`, had the complete macOS 26 and Ubuntu 24.04
  matrix green. The newly pushed compatibility follow-up still needs its own GitHub Actions result.

## Deliberate non-changes and residual coverage

- Do not revisit TTY detection as part of this pass. A possible non-CI, headless Linux edge case was
  discussed, but the user explicitly chose not to change it.
- CI proves real x86_64 Ubuntu 24.04 behavior, including a fresh Homebrew install. It does not prove
  arm64 Linux, other distributions, older glibc/sudo combinations, or every custom sudoers setup.
- The arm64 path is structurally supported through architecture normalization, Homebrew's canonical
  Linux prefix, and arm64 artifacts, but it does not yet have live CI coverage.
- Keep Linux checks distribution-neutral. Do not add `apt`, `dnf`, or another distro package manager
  to the bootstrap.
- Keep Bubblewrap under Homebrew's ownership rather than restoring it as a hard `bootbox`
  prerequisite.

## Resume checklist

1. Check PR #11's newest Actions run, especially `homebrew` on macOS and Ubuntu.
2. If a job fails, inspect the first failing command rather than later cascading output.
3. Keep fixes narrow and commit issue by issue with lowercase `#11:` subjects.
4. Run `bun run lint` and `git diff --check`; leave `dist/` untouched.
5. Once the newest matrix is green, review the complete PR diff and decide whether to keep this
   handoff document in the final merge.

On the source machine used to create this handoff, `gh auth status` reported an invalid CLI token,
although public PR reads worked and the repository remote uses SSH. Reauthenticate `gh` on the new
machine if PR or Actions commands require it.
