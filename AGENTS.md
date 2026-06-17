# Repo Guidance For `bootbox`

Apply broader or global Codex guidance first, then apply this repo-local file.
When this file conflicts with broader defaults, this file wins for work in `bootbox`.

## Purpose

- This repo owns Bootbox, the reusable upstream macOS 26.x bootstrap layer for Homebrew,
  Brewfiles, dotpackages, and 1Password-backed SSH key material.
- Downstream machine profiles such as `me`, `emori`, and `agentbox` may wrap Bootbox, but wrapper
  concerns should stay in those repos unless Bootbox's generic contract is intentionally changed.

## Source Of Truth

- [`bootbox.sh`](/Users/pirog/tanaab/bootbox/bootbox.sh) is the source shell entrypoint and main
  bootstrap surface.
- [`README.md`](/Users/pirog/tanaab/bootbox/README.md) is the human-facing setup, usage, and support
  surface.
- [`examples/**/README.md`](/Users/pirog/tanaab/bootbox/examples) files are Leia-backed executable
  contract specs consumed in CI.
- [`dist/`](/Users/pirog/tanaab/bootbox/dist) is generated publish output for Netlify hosting and
  release preparation.
- [`scripts/build-dist.js`](/Users/pirog/tanaab/bootbox/scripts/build-dist.js),
  [`site/`](/Users/pirog/tanaab/bootbox/site), `netlify.toml`, release workflows, and committed
  `dist/` files own the hosted-script publishing surface.

## Build Artifacts

- Do not edit, regenerate, stage, or commit files under `dist/` during local agent work.
- `dist/` is CI/release-owned output. GitHub Actions may regenerate and stamp it during build,
  test, release, or hosting workflows.
- Make source changes in `bootbox.sh`, `site/`, or `scripts/build-dist.js`; leave `dist/`
  unchanged unless the user explicitly asks for a local generated-artifact update.
- Treat `bootbox.sh` as the source entrypoint and `dist/bootbox.sh` as the release-shaped hosted
  artifact prepared by build and release workflows.
- Preserve the source script's single top-level `SCRIPT_VERSION` assignment pattern so release
  stamping with `version-injector` keeps working.
- Do not run `bun run build` locally unless the user explicitly asks for local generated-output
  verification. Prefer GitHub Actions for build/release artifact validation.

## CLI Contract

- Keep `--help` as the public CLI contract surface.
- When changing option names, environment variables, help text, hidden flags, version output,
  failure wording, debug output, planning output, or status messages, update affected README
  usage/configuration content and Leia examples in the same change.
- Any `bootbox.sh` public interface change must check `README.md`, `examples/bootbox-cli-contract`,
  and the affected mutating examples.
- Keep `--check-core` hidden from `--help`; it is an intentionally undocumented 0/1 readiness probe
  for Bootbox's built-in Homebrew core only.
- Keep `--check-core` quiet under normal operation; if its behavior changes, update the CLI
  contract example explicitly.
- Keep `--no-sudo` as a strict no-elevation mode: no sudo probes, prompts, timestamp cleanup, or
  sudo-backed helper operations.
- Keep planned-action output aligned with actual execution order.

## Secrets And Logging

- Never print raw 1Password service account credentials in debug, help, or error output.
- Mask token-bearing values from `--op-token`, `BOOTBOX_OP_TOKEN`, legacy `TANAAB_OP_TOKEN`, and
  `OP_SERVICE_ACCOUNT_TOKEN` when they appear in any diagnostic surface.
- Preserve the repo's CLI color conventions for status verbs and targets; use the established
  Tanaab styles rather than ad hoc color choices for action labels such as `running`.

## Leia Example Style

- Leia examples under `examples/` are CI-owned executable scenarios. They may mutate GitHub-hosted
  macOS runners, but should not be treated as routine local validation.
- Prefer direct command pipelines, command substitutions, and deterministic inline values over
  writing files just to inspect them later.
- Do not capture command output into shell variables just to grep it later. Leia failure output must
  surface useful stdout/stderr in CI; prefer direct commands or `cmd | tee /dev/stderr | grep ...`
  when an assertion needs both matching and diagnostics.
- Treat each blank-line-separated Leia block as a separate script. Do not rely on shell variables,
  functions, or working-directory changes persisting across `should` blocks.
- Use `TMPDIR` for durable fixtures, unavoidable logs, and helper internals only.

## Validation Policy

- Prefer the narrowest reliable checks for the touched surface.
- For routine local validation, use `bun run lint`.
- For shell changes, start with the narrowest relevant check such as `shellcheck bootbox.sh` or
  `bun run lint:shellcheck`.
- Run `git diff --check` when whitespace or generated text churn is plausible.
- Run `bun install` when dependencies are missing before linting, and keep `bun.lock` as a tracked
  dependency artifact when Bun updates it.
- Do not run `bootbox.sh`, `dist/bootbox.sh`, or Leia examples as routine local validation unless
  the user explicitly asks for local execution. Non-mutating help checks are acceptable when a
  README/development task specifically calls for them.
- Do not treat local `dist/` regeneration as part of normal validation; if build-artifact
  verification matters, say it was deferred to CI.
- Live 1Password-backed SSH key validation remains CI-owned because it depends on the
  `BOOTBOX_OP_TESTVAULT` CI environment value on fresh macOS runners.

## Release And Distribution

- Netlify publishes committed `dist/`, but local agents should not update it directly; CI/release
  workflows own generated `dist/` changes.
- Release workflows use the Bootbox-style shell-script distribution flow. Keep `dist/bootbox.sh` as
  the stamped hosted entrypoint.
- Do not add unrelated package archives or upload behavior unless the release contract explicitly
  changes.
- Generated hosting changes should check `scripts/build-dist.js`, `site/`, `dist/`, `netlify.toml`,
  and release workflow assumptions together.

## `bootbox.sh` Invariants

- Preserve the public `BOOTBOX_*` namespace. Legacy `TANAAB_*` support is compatibility-only and
  should not be documented outside code or explicit legacy behavior tests.
- Preserve `--check-core` as a hidden, quiet probe for built-in Homebrew core readiness only.
- Preserve token masking in debug output and do not reintroduce raw argument logging.
- Keep repeatable CLI inputs replacing env-sourced lists when any corresponding CLI flag is
  provided.
- Treat empty inline repeatable inputs such as `--brewfile=` or `--ssh-key=` as intentional list
  clearing; do not treat an empty `--target=` as meaningful.
- Prefer targeted edits to `bootbox.sh`; avoid whole-file rewrites unless the script contract is
  being intentionally replaced.
