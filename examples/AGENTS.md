# Leia Example Guidance

This file applies when editing `examples/**/README.md`. These README files are executable Leia
specs consumed in CI.

## General Style

- Prefer behavior-focused `# should` labels.
- Keep each `# should` block focused on one observable contract.
- Treat each blank-line-separated Leia block as a separate script. Do not rely on shell variables,
  functions, or working-directory changes persisting across `should` blocks.
- Prefer direct command pipelines, command substitutions, and deterministic inline values over
  writing files just to inspect them later.
- Prefer direct output assertions with `cmd 2>&1 | tee /dev/stderr | grep ...` or a focused `awk`
  check over redirecting output to `.tmp/*.log` and grepping it later.
- Do not capture command output into shell variables just to grep it later. If capture is needed to
  preserve a failing command's status, print the captured output before assertions.

## Fixtures

- Keep fixtures beside the scenario README so each example stays self-contained.
- Prefer committed example-local fixture binaries or files over generating long fixtures with
  heredocs inside the README.
- Hide repeated fixture environment and argument setup behind committed example-local helper scripts
  when it makes README commands clearer.
- Use `.tmp/` for scenario scratch data, logs, patched script copies, and helper internals.
- Avoid braced shell variable expansions such as `${VAR}` in README command blocks when `$VAR` works.

## Scenario Shape

- Use `## Setup`, `## Testing`, and `## Destroy tests`.
- Keep `Setup` focused on minimal prerequisites for the scenario.
- Put commands immediately below each `# should ...` line with no blank lines inside the test body.
- Separate one `# should ...` test from the next with a blank line.
- Always include cleanup in `Destroy tests`, and remove only artifacts created by that scenario.

## Local Validation

- Do not run Leia examples locally as routine validation. They are CI-owned executable scenarios and
  may mutate the machine.
- Non-mutating CLI contract checks may be run locally when they are the touched surface and the user
  has not asked to avoid local Leia execution.
- Mutating runtime examples should be left to GitHub-hosted macOS CI unless the user explicitly asks
  for local execution.
