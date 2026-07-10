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

## Example Placement

- `inputs` owns non-mutating public interface checks: help text, displayed defaults, input
  validation, and option/env precedence.
- `defaults` owns the baseline happy-path bootstrap and core-readiness contract.
- Named domain examples own focused behavior such as Brewfiles, dotpackages, SSH keys, legacy
  compatibility, and sudo handling. Input-source behavior belongs in `inputs`, not duplicate
  mutating domain examples.
- Add coverage to the narrowest existing example that owns the behavior. Add a new example only
  when the behavior needs incompatible setup or would blur an existing domain.

## Fixtures

- Keep real input fixtures beside the scenario README so each example stays self-contained.
- Prefer the prepared `bootbox` entrypoint and real runner tools, users, permissions, and machine
  mutations over fixture binaries that emulate runtime dependencies.
- When simulation is unavoidable, prefer a committed example-local helper over generating a long
  fixture with a heredoc inside the README.
- Hide repeated fixture environment and argument setup behind committed example-local helper scripts
  when it makes README commands clearer.
- Use `.tmp/` for scenario scratch data, logs, patched script copies, and helper internals.
- Avoid braced shell variable expansions such as `${VAR}` in README command blocks when `$VAR` works.

## Scenario Shape

- Use `## Setup` and `## Testing`.
- Keep `Setup` focused on minimal prerequisites for the scenario.
- Let the workflow and runtime provide CI/non-TTY context. Do not set `CI` or `NONINTERACTIVE`
  inside example commands.
- Mutating domain examples should normally run `bootbox` once. Use multiple successful runs only
  when rerun, idempotency, or distinct execution modes are the scenario contract.
- Put commands immediately below each `# should ...` line with no blank lines inside the test body.
- Separate one `# should ...` test from the next with a blank line.
- Do not add destroy or cleanup sections for runner-local state. Each example runs in its own fresh
  GitHub-hosted macOS job, and the VM is discarded after the job.
- If examples ever run on persistent infrastructure or mutate shared external state, change the
  execution policy centrally before adding targeted cleanup back to individual scenarios.

## Local Validation

- Do not run Leia examples locally as routine validation. They are CI-owned executable scenarios and
  may mutate the machine.
- Non-mutating CLI contract checks may be run locally when they are the touched surface and the user
  has not asked to avoid local Leia execution.
- Mutating runtime examples should be left to GitHub-hosted macOS CI unless the user explicitly asks
  for local execution.
