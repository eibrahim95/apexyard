# Git identity propagation and target precedence

> In the context of workflows that create or clone repositories, facing missing repository-local Git identity and incorrect first-commit attribution, I decided to copy the ops fork's resolved identity only into target fields that Git does not resolve, so that created repositories inherit a usable identity without overriding deliberate target configuration, accepting repeated workflow snippets across the standalone skills.

## Context

- The ops fork can have a repository-local `user.name` and `user.email`.
- A sibling repository does not inherit repository-local configuration from the ops fork.
- Git can therefore create the first sibling-repository commit with a hostname-derived identity.
- A target repository can already resolve an intentional identity from local or global configuration.
- The policy applies across `/setup`, `/split-portfolio`, and `/handover`.

## Options Considered

| Option | Pros | Cons |
|---|---|---|
| Rely on the target repository's existing configuration | No additional workflow logic | Misses repository-local identity from the ops fork and can create incorrect first-commit attribution |
| Always copy the ops fork's identity into the target repository | Keeps the workflows uniform and fixes missing local configuration | Overwrites a deliberate target identity from local or global configuration |
| Fill only unresolved target values and prompt for missing source values | Preserves target intent, carries the ops fork identity when needed, and stops before an identity-less first commit | Repeats a guarded block in three standalone skills |

## Decision

Chosen: **fill only unresolved target identity values from the ops fork, and prompt for missing source values.**

- Read `user.name` and `user.email` with `git config --get` from the ops fork.
- Prompt for each missing source value before the workflow reaches its first commit.
- Read each target value with `git config --get` before writing it.
- Write a target value only when Git cannot resolve that value from local or global configuration.
- Keep the logic in each skill because the skills must remain independently actionable and the Zed adapter exports their bodies.

## Consequences

- New portfolio repositories and managed-project clones inherit the ops fork identity when their target configuration is incomplete.
- Existing target-local and target-global identities remain unchanged.
- Operators receive an explicit prompt when the ops fork has no complete identity.
- The contract test checks the policy in all three canonical skills.
- Future changes to the precedence policy must update all three skills and the contract test.

## Artifacts

- [Issue #11](https://github.com/eibrahim95/apexyard/issues/11)
- [PR #14](https://github.com/eibrahim95/apexyard/pull/14)
