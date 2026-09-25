# PR title scopes and issue linking

> In the context of Conventional Commit-style PR titles, facing ticket IDs occupying the scope position and hiding the affected component, I decided to put the component in the scope and move the tracker reference to the PR body to make titles useful to readers while preserving issue validation and auto-close behavior, accepting that the validator and contributor guidance must change together.

## Context

- The current title format is `type(TICKET): description`.
- Conventional Commits uses the optional scope to name a codebase section, such as `parser`.
- GitHub recognizes closing keywords such as `Closes #123` in PR bodies.
- Branch names already carry the ticket ID and remain unchanged.
- The PR validator currently extracts and verifies the ticket reference from the title.

## Options Considered

| Option | Pros | Cons |
|---|---|---|
| Keep `type(TICKET): description` | Preserves current validation and usage | Uses the scope position for a tracker ID instead of affected code |
| Use `type(scope): description` and link the issue in the PR body | Gives readers component context and supports GitHub auto-close | Requires coordinated validator, test, and documentation changes |
| Put both scope and ticket ID in the title | Keeps a visible issue number and adds component context | Adds title noise and does not use GitHub's body-based closing mechanism |

## Decision

Chosen: **use `type(scope): description` and link the ticket in the PR body**, because the scope should identify the affected component while the body can carry the tracker reference and GitHub closing keyword.

Keep the ticket ID in the branch name. Require one real, open ticket reference in the PR body. For GitHub Issues, use a closing keyword such as `Closes #123`. Preserve the existing one-ticket-per-PR rule and tracker-aware existence check.

## Consequences

- PR titles provide component context instead of a ticket number.
- GitHub links the issue, and closes it when the PR merges into the default branch.
- The PR validator reads the first closing reference from the body and runs the existing existence and open-state check on it.
- A cross-repo reference (`Closes owner/repo#N`) does not satisfy the check. Use a bare `Closes #N`.
- Tests and all contributor guidance must use the new title and body format.
- Existing PR commands that use the old title format must be updated before creating new PRs.

## Artifacts

- [Issue #3](https://github.com/eibrahim95/apexyard/issues/3)
