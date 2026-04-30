# GitHub Copilot Instructions for FirelyTeam/azure-pipeline-templates

This repository contains reusable Azure Pipelines YAML templates that are
consumed by multiple Firely repositories (Vonk, Vonk.Plugins, Helm.Charts,
and others). Changes here can affect every consumer pipeline, so caution
and backwards-compatibility are paramount.

## Repository purpose

- **Template-only repo.** Each `.yml` file is a stand-alone, parameterised
  template (stage / job / steps / variable). There is no build of this
  repo itself — its "release" is a git tag (`v1`, `v2`, ...) that consumers
  reference via `ref: refs/tags/v<n>`.
- Consumers reference templates through the `resources.repositories`
  block, e.g.:
  ```yaml
  resources:
    repositories:
      - repository: templates
        type: github
        name: FirelyTeam/azure-pipeline-templates
        endpoint: FirelyTeam
        ref: refs/tags/v1
  ```
- A breaking change to a template breaks every consumer that picks up the
  new tag. **Prefer additive, backwards-compatible changes.**

## General authoring rules

- **Two-space indentation.** Azure Pipelines YAML is indentation-sensitive.
- **Use file-scoped templates.** One template per file; the filename should
  match the role of the template (`build.yml`, `push-nuget-package.yml`,
  `check-skip-stage.yml`).
- **Document every parameter.** Each `parameters:` entry must include a
  short description (either as a `displayName` or a YAML comment) and a
  sensible `default` where one exists.
- **Top-of-file header comment.** Each template starts with:
  ```yaml
  # Repo: FirelyTeam/azure-pipeline-templates
  # File: <relative path>
  #
  # <one-paragraph description of what the template does>
  #
  # Usage: <minimal example showing the template being included>
  ```
- **Keep parameter names camelCase** (`vmImage`, `ignorePatterns`,
  `firelySdkVersion`). Match the casing used elsewhere in the repo.
- **Group related parameters.** Order: identity (name/displayName), inputs,
  toggles, advanced/rare overrides last.

## Backwards compatibility

- Treat a tag (`v1`, `v2`, ...) as a stable contract. Changes that ship
  inside a tagged major version must be **non-breaking**.
- Non-breaking changes:
  - Adding new optional parameters with sensible defaults.
  - Adding new output variables.
  - Internal refactors that preserve inputs, outputs, side effects.
- Breaking changes (require a new major tag):
  - Removing or renaming an existing parameter.
  - Changing a parameter's default in a way that changes pipeline
    behaviour for existing callers.
  - Renaming or removing an output variable.
  - Changing the published artifact name, container image tag scheme,
    or any other externally observable side effect.
- When in doubt, **assume external consumers exist** and ask before
  making the change.

## Branching and review

- Work on `feature/<JIRA-key>-<short-description>` or
  `fix/<JIRA-key>-<short-description>` branches.
- Every change goes through a PR to `main`. PRs are reviewed by the
  DevOps / infra owners.
- Test changes end-to-end by temporarily pointing a consumer pipeline's
  `ref:` at the feature branch (e.g.
  `ref: refs/heads/feature/DEVOPS-XXX-...`) and running a real CI build.
  **Revert the ref to a tag before merging the consumer's PR.**
- Once merged to `main`, retag (`git tag -f v1 main`) so consumers
  pinned to `v1` pick up the change.

## PowerShell inside templates

Several templates embed inline PowerShell in `- powershell: |` blocks.
The agents run on Linux (`ubuntu-latest`) using PowerShell 7+.

- **Force array context** when capturing native command output:
  `$x = @(git diff --name-only ... | Where-Object { $_ })`. A single-line
  result is otherwise stored as a scalar string and `.Count` / array
  semantics break.
- **Don't rely on `HEAD~1`** alone — guard with `git rev-parse --verify`
  or use a fallback such as `git show --name-only --pretty='' HEAD`.
- **Use `Write-Host` for log output** and `##[group]` / `##[endgroup]`
  to make logs collapsible in the Azure DevOps UI.
- **Set output variables** with the canonical syntax:
  `Write-Host "##vso[task.setvariable variable=<name>;isOutput=true]<value>"`.
  Pair with `name: <stepName>` on the step so consumers can reference
  `dependencies.<stage>.outputs['<job>.<stepName>.<variable>']`.
- **Distinct step / job names.** Don't reuse the job name as the step
  name — it produces awkward `foo.foo.var` output references. Use a
  descriptive step name (`evaluateIgnorePatterns`, `computeVersion`).

## Azure DevOps variable gotchas

- `System.PullRequest.TargetBranch` contains `refs/heads/<name>` (full
  ref) — **don't** prefix it with `origin/` directly.
- `System.PullRequest.TargetBranchName` contains the bare branch name
  (`<name>`) and is what you usually want for `git diff origin/<name>`.
- `Build.Reason` values include `IndividualCI`, `BatchedCI`,
  `PullRequest`, `Manual`, `Schedule`, `ResourceTrigger`. Branch CI
  pushes go through `IndividualCI` / `BatchedCI`, **not** `PullRequest`.

## Don'ts

- **Don't** introduce hard dependencies on consumer-specific paths,
  variables, or service connections without parameterising them.
- **Don't** hardcode credentials, tokens, or service-connection names —
  always accept them as parameters.
- **Don't** silently change the default `vmImage` — different images
  have different pre-installed tooling.
- **Don't** add a step that requires elevated permissions (e.g.
  `secureFile`, signed-package upload) to a template intended for use
  in PR builds — PRs from forks generally cannot access secrets.

## Commit and PR style

- Commit messages: imperative mood, JIRA key in parentheses at the end
  of the subject (`Fix array unwrap in check-skip-stage (DEVOPS-706)`).
- PR description should call out:
  - What changed.
  - Whether the change is backwards-compatible.
  - Which consumer repos / pipelines were used to test the change.
  - Whether a new tag (`v<n+1>`) is required after merge.

_This file guides Copilot, Claude Code, and other AI-assisted tooling
working in this repo. Keep it up to date as conventions evolve._
