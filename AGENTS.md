# Repo Guidance For `bootbox`

This root file should stay broadly applicable to repository work. Put narrower policy closer to the
files it governs, such as `examples/AGENTS.md` for Leia examples.

## Purpose

`bootbox` is the reusable upstream macOS and Linux bootstrap layer for Homebrew, Brewfiles,
current-user dotpackages, and 1Password-backed SSH key material. Downstream machine profiles such as
`me`, `emori`, and `agentbox` may wrap it, but wrapper-specific behavior belongs in those
repositories unless the generic `bootbox` contract is intentionally changed.

## Scope

In scope:

- Homebrew installation and built-in core readiness on supported macOS and Linux systems.
- Applying local or remote Brewfiles as the invoking user.
- Stowing current-user dotpackages into `$HOME`.
- Installing 1Password-backed private SSH keys into `$HOME/.ssh`.
- Hosted-script, Netlify metadata, release, and Leia-backed executable contract surfaces.

Out of scope:

- Persona-, workspace-, or machine-profile-specific behavior owned by downstream wrappers.
- Privileged host configuration, service supervision, SSH daemon hardening, or remote-access policy.
- Distribution-specific package-manager invocation or automatic Linux prerequisite installation.
- Homebrew group creation, permission repair, or unsupported multi-user ownership management.
- Automatic shell startup-file edits or configuration of another user's home.

## Direction

This is directional guidance, not an expansion of the current public contract:

- Keep the hosted shell entrypoint as the primary bootstrap path.
- Keep `bootbox` narrow, current-user-oriented, and reusable by downstream wrappers.
- Prefer capability checks and platform-native Homebrew behavior over distribution-specific setup.
- Add new privileged, multi-user, or machine-profile behavior only when the product contract is
  explicitly expanded.

## Source Map

- `bootbox.sh`: source shell entrypoint and main bootstrap contract.
- `README.md`: primary setup and common-usage entrypoint.
- `ADVANCED.md`: installed components, platform behavior, complete public configuration reference,
  and shared Homebrew guidance.
- `examples/**/README.md`: Leia-backed executable CI contracts.
- `site/llms.txt`, `scripts/build-dist.js`, and `netlify.toml`: hosted metadata and distribution
  publishing sources.
- `assets/`: repository-facing visual assets used by documentation.
- `dist/`: generated Netlify and release output owned by CI and release workflows.

## Critical Rules

- Style the project, repository, and CLI name as lowercase `bootbox` in prose and user-facing
  output. Example H1 titles may capitalize the leading `B` when the title begins with the project
  name.
- Preserve literal identifiers exactly, including commands, paths, URLs, environment variables,
  labels, generated strings, repository names, and fixture values.
- Do not edit, regenerate, stage, or commit `dist/` during routine local work. Change source inputs
  and leave generated output to CI unless the user explicitly requests release-shaped verification.
- Do not run `bun run build` locally unless the user explicitly asks for generated-output
  verification.
- Preserve the source script's single top-level `SCRIPT_VERSION` assignment so release stamping
  with `version-injector` keeps working.
- Keep `/llms.txt` concise in `site/llms.txt`; `scripts/build-dist.js` copies it into `dist/`.
- Keep `--help` as the public CLI contract. Public option, environment-variable, help, planning,
  status, debug, or failure-text changes must check `README.md`, `ADVANCED.md`,
  `site/llms.txt`, and affected examples.
- Do not document hidden development, compatibility, or CI-only inputs as public configuration.
- Preserve the public `BOOTBOX_*` namespace. Legacy `TANAAB_*` support is compatibility-only and
  should appear only in code or explicit legacy behavior tests.
- Never print raw 1Password service account credentials. Mask token-bearing values from
  `--op-token`, `BOOTBOX_OP_TOKEN`, legacy `TANAAB_OP_TOKEN`, and
  `OP_SERVICE_ACCOUNT_TOKEN` in every diagnostic surface.
- Preserve the established Tanaab CLI colors and action-label styles rather than introducing
  one-off output conventions.

## `bootbox.sh` Invariants

- Keep `--check-core` hidden from `--help`. It is an intentionally undocumented, quiet 0/1 probe
  for built-in Homebrew core readiness only.
- Keep `--no-sudo` strict: no sudo probes, prompts, timestamp cleanup, or elevation.
- Keep `$HOME` as the only SSH-key and dotpackage destination. Do not add a public target override
  or elevate current-user file operations.
- Keep sudo limited to installing missing Homebrew. Existing Homebrew must already be manageable by
  the invoking user through ownership or trusted group access.
- Authorize sudo only after showing the interactive plan. Use `sudo -n` under `NONINTERACTIVE` or
  `CI`, and do not probe or prompt when existing Homebrew is manageable.
- Keep missing-Homebrew Linux prerequisite checks capability-based and distribution-neutral. Check
  commands, versions, and glibc before confirmation or sudo; never invoke a distro package manager.
- Let Homebrew choose between a usable system Ruby and portable Ruby. Do not make Ruby or Bubblewrap
  an unconditional `bootbox` prerequisite.
- Treat shared Homebrew groups as manual, advanced, upstream-unsupported configuration. Do not add
  group or permission remediation to `bootbox.sh`.
- Never edit shell startup files. Print only the conditional post-install `brew shellenv` reminder.
- Resolve interactive input through `/dev/tty` when available so hosted pipe-to-Bash invocations
  can confirm the plan. Treat `INTERACTIVE` as a requirement and fail when no interactive terminal
  exists.
- Keep repeatable CLI inputs replacing environment-sourced lists when any corresponding CLI flag is
  supplied.
- Treat empty inline repeatable inputs such as `--brewfile=` or `--ssh-key=` as intentional list
  clearing.
- Keep planned-action output aligned with actual execution order.
- Prefer targeted edits to `bootbox.sh`; avoid whole-file rewrites unless the script contract is
  intentionally replaced.

## Examples And Leia

- Examples are executable Leia specs consumed in CI, not prose-only documentation.
- Keep `examples/inputs` non-mutating; it owns the public CLI contract, displayed defaults, input
  validation, precedence, and list-clearing behavior.
- Keep named domain examples focused on defaults, Homebrew installation, Brewfiles, dotpackages,
  SSH keys, sudo boundaries, and legacy compatibility.
- Mutating scenarios may run on GitHub-hosted macOS and Ubuntu runners but should not be treated as
  routine local validation.
- Do not rely on state persisting across blank-line-separated Leia blocks.
- Keep diagnostic output visible in CI; prefer direct pipelines or focused `awk` checks that print
  each input line while tracking assertion state.
- See `examples/AGENTS.md` before editing example scenarios or fixtures.

## Release And Distribution

- Netlify publishes committed `dist/`, while CI and release workflows own generated changes.
- `bootbox.sh` is the source entrypoint; `dist/bootbox.sh` is the stamped hosted artifact.
- Release workflows use the shell-script distribution flow and should not gain unrelated archives or
  upload behavior unless the release contract changes.
- Generated hosting changes should check `scripts/build-dist.js`, `site/`, `dist/`,
  `netlify.toml`, and release workflow assumptions together.

## Validation

- Prefer the narrowest reliable checks for the touched surface.
- Use `bun run lint` for routine local validation and `git diff --check` when text churn is
  plausible.
- For shell changes, start with `bun run lint:shellcheck` or the narrowest equivalent check.
- Run `bun install` when dependencies are missing and keep `bun.lock` when Bun updates it.
- Do not run `bootbox.sh`, `dist/bootbox.sh`, or mutating Leia examples as routine local
  validation unless the user explicitly asks. Non-mutating help checks are acceptable for CLI or
  documentation work.
- Treat `bun run build`, generated `dist/` verification, and live 1Password-backed SSH-key
  scenarios as CI-owned unless explicitly requested.
- When build, Leia, or live secret-backed verification is intentionally skipped, say so plainly.

## References

- `README.md`, `ADVANCED.md`, `CHANGELOG.md`
- `examples/`, `examples/AGENTS.md`
- `site/llms.txt`, `scripts/build-dist.js`, `netlify.toml`
