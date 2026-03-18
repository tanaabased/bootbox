# Repo Agent Guidance

Apply broader or global Codex guidance first, then apply this repo-local file.
When this file conflicts with broader defaults, this file wins for work in `bootbox`.

## Build Artifacts

- Treat `dist/` as CI-owned generated output.
- Do not run `bun run build` locally unless the user explicitly asks for a local build.
- Do not hand-edit generated files under `dist/`; make source changes in repo-owned inputs such as [`bootbox.sh`](/Users/pirog/tanaab/bootbox/bootbox.sh), [`site/`](/Users/pirog/tanaab/bootbox/site), or [`scripts/build-dist.js`](/Users/pirog/tanaab/bootbox/scripts/build-dist.js) and leave artifact generation to CI unless the user explicitly asks otherwise.
- Treat [`bootbox.sh`](/Users/pirog/tanaab/bootbox/bootbox.sh) as the source entrypoint and `dist/bootbox.sh` as the release-shaped artifact prepared in CI via the release workflows.
- Preserve the source script's single top-level `SCRIPT_VERSION` assignment pattern so CI release stamping with `version-injector` keeps working.

## CLI Contract

- Treat the README files under [`examples/`](/Users/pirog/tanaab/bootbox/examples) as executable contract specs consumed by Leia in CI, not just prose examples.
- When changing help text, option names, hidden flags, version output, failure wording, or debug/status messages, review and update the affected example README assertions in the same change.
- Keep `--help` as the public CLI contract surface.
- Keep `--check-core` hidden from `--help`; it is an intentionally undocumented 0/1 readiness probe for Bootbox's built-in Homebrew core only.
- Keep `--check-core` quiet under normal operation; if its behavior changes, update the CLI contract example explicitly.

## Secrets And Logging

- Never print raw 1Password service account credentials in debug, help, or error output.
- Mask token-bearing values from `--op-token`, `TANAAB_OP_TOKEN`, and `OP_SERVICE_ACCOUNT_TOKEN` when they appear in any diagnostic surface.
- Preserve the repo's CLI color conventions for status verbs and targets; use the established Tanaab styles rather than ad hoc color choices for action labels such as `running`.

## Validation

- For shell changes, start with the narrowest relevant check such as `shellcheck bootbox.sh` or `bun run lint:shellcheck`.
- Do not treat local `dist/` regeneration as part of normal validation; if build-artifact verification matters, say it was deferred to CI.
- Leia example scenarios under `examples/` remain CI-owned unless the user explicitly asks for a local Leia run.
- Live 1Password-backed SSH key validation remains CI-owned because it depends on the `TANAAB_OP_TESTVAULT` secret on fresh macOS runners.
