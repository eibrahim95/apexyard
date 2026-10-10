---
name: walking-skeleton-django
description: Bootstrap a Django walking skeleton with cookiecutter-django, Basecoat, Celery, Channels, and a Cloud Build deploy to Cloud Run. Kept, full SDLC.
argument-hint: "<app-name> — <one-line purpose>"
allowed-tools: Bash, Read, Write, Edit, WebSearch, WebFetch
---

# /walking-skeleton-django — Bootstrap a Django App as the Thin End-to-End Slice

Read `.claude/rules/writing-standard.md`. Use the **controlled technical writing profile** for the
ticket, the README, the AGENTS.md, and every other durable artifact this skill writes.
Remove empty sections.

This is the Django form of [`/walking-skeleton`](../walking-skeleton/SKILL.md). It does two jobs in one flow:

1. It generates a new Django app and wires it through every layer: browser, Django, Celery, Postgres and Redis, and a GCP deploy path.
2. It files the `[Feature]` walking-skeleton ticket that tracks the work, with the same ticket shape as `/walking-skeleton`.

The skeleton is **KEPT**. It gets the full SDLC. It is **not** exempt from the AgDR or coverage gates the way `/spike` and `/prototype` are. See `.claude/rules/workflow-gates.md`.

Use `/walking-skeleton` instead when the stack is not Django.

## Path resolution

Resolve every portfolio path with the helper. Do not hardcode them.

```bash
source "$(git rev-parse --show-toplevel)/.claude/hooks/_lib-read-config.sh"
source "$(git rev-parse --show-toplevel)/.claude/hooks/_lib-portfolio-paths.sh"
registry=$(portfolio_registry)
projects_dir=$(portfolio_projects_dir)
workspace_dir=$(portfolio_workspace_dir)   # portfolio.workspace_dir
```

- The app **repo** is generated into `<workspace_dir>/<app-name>/`.
- Put the PRD and designs in `<projects_dir>/<app-name>/docs/`. Do not put them in `_inbox`.
- Write each app AgDR in the app repo at `docs/agdr/`. Do not put an app AgDR in the portfolio.

## Usage

```
/walking-skeleton-django billing-portal — invoices and payments for small agencies
/walking-skeleton-django field-notes
```

## How to work

Work through the process in order. This skill already decides the common choices, so do not ask about them. Do not re-ask about any option or default stated here.

Ask the operator when you need to. Ask in these cases:

- Before you create the GitHub repo (step 6). After it exists, ask whether to link it to a GitHub Project.
- Before you file the ticket (step 7).
- A required input is missing or unclear.
- Two instructions in this skill conflict.
- A choice is not covered here and the answer changes the design, the dependencies, or the infrastructure.
- A step fails and you cannot fix it with a small, safe change.
- An action is hard to reverse or visible outside this machine, and this skill does not authorise it.

When you ask, ask one focused question at a time. The one exception is the step 1 input batch. Give a recommended answer and the reason. Keep going on the parts that do not depend on the answer.

Show the plan and the planned file tree before you build. Report what is verified and what is not.

## Stack and architecture rules

Core model: the server owns the page and the client animates it. This is a hypermedia app that feels like an SPA. It is not an SPA.

- Django 6.x handles routing, ORM, auth, and business logic.
- django-basecoat is the UI library for the whole app. It is Basecoat (the shadcn/ui design system without React) as django-cotton components. Make full use of it.
  - Before you build any UI, read the django-basecoat README and its demo site (https://django-basecoat.ignacemaes.com/). List the components it ships. Record that list in the new repo's AGENTS.md.
  - Build every screen from Basecoat components. These include button, card, input, select, checkbox, dialog, dropdown menu, tabs, table, alert, badge, breadcrumb, avatar, and accordion. Use the rest of what it ships too.
  - When a needed element has no django-basecoat component, use the Basecoat CSS classes directly. Wrap the result in a project cotton component in `templates/cotton/`.
  - Write a custom component only when neither Basecoat option exists. Never hand-roll a dropdown, dialog, select, or tabs.
  - Style the app through Basecoat's theme tokens. Do not add a second component library. Do not use Web Awesome.
  - After an Unpoly update, re-bind Basecoat widgets in an `up.compiler()` that returns a cleanup function. Do not call `dialog.showModal()` inside a layer. Unpoly already opened the overlay.
- django-cotton 2.x provides server-side components with slots and props. Components live in `templates/cotton/` and stay presentational. Business logic stays in views and services.
- Unpoly 3.x owns navigation. Use the `unpoly` package and `UnpolyMiddleware`. Do not implement the protocol. Put form, layer, and delete mixins in `unpoly_mixins.py`.
  - Every URL returns one full HTML document. Unpoly extracts a region from it. Do not return a fragment-only body. Do not add a JSON endpoint for UI.
  - Root content is `<main up-main>`. A modal page marks its region `up-main="modal"`. A direct visit renders that page. An overlay extracts the same region.
  - Open a modal with one control: `<c-button type="button" up-href="/welcome/" up-follow up-layer="new">`. Never nest a button in an `<a>`. Unpoly follows `a[href]` and `[up-follow]` only.
  - `.up-modal-box` is the only frame. Do not put a card inside it. Set its background to `var(--color-surface)`.
- Alpine.js 3.x owns local state. Do not use it to navigate.
  - Load `static/js/app.js` with `defer`, before the Alpine script. Register the theme store inside `alpine:init`. A script after Alpine misses that event.
  - On `up:fragment:inserted`, call `Alpine.initTree` on the inserted fragment only.
- Tailwind CSS 4.x uses CSS-first configuration: `@theme {}`, no `tailwind.config.js`, no content array. Name tokens by function (`--color-surface`), not by colour.
- Initialise other page scripts with `up.compiler()` and return a cleanup function. Do not use `DOMContentLoaded` for swapped content.
- Bake in dark mode from the first commit with a three-way toggle: system, light, dark.
  - Put `data-theme` on `<html>`.
  - Add a synchronous inline script before paint to prevent a flash of the wrong theme.
  - Keep the toggle state in an Alpine store persisted in localStorage. This also covers the logged-out pages.
  - Wire Tailwind with `@custom-variant dark (&:where([data-theme="dark"], [data-theme="dark"] *))`.
  - Set `color-scheme` on `:root` to match.
  - Make Basecoat follow the same theme. Check how Basecoat selects its dark palette. If it uses a different hook than `data-theme`, bridge the two with a custom variant or a token mapping.
- Use this folder layout: `templates/cotton/` (components, including a theme toggle), `templates/layouts/` (base, app, auth), `templates/partials/` (includes, not URLs), `templates/pages/`, `static/js/` (`app.js` and `compilers/`), `static/css/`, and `unpoly_mixins.py`.

## Docker policy

The skill decides Docker once. Later steps refer to this section.

- Cookiecutter runs with `use_docker=y`.
- Generation needs Docker. With `use_docker=y`, the cookiecutter hook builds a small image and runs `uv add` inside it. The hook exits with an error if the Docker daemon is not running.
- Local development uses `.venv`, the justfile, and Zed tasks. It does not use Docker.
- Keep the generated local compose files. A teammate may use them.
- Do not edit or delete the generated local compose files.
- Adapt the generated production Dockerfile and start script in place for Cloud Run. Do not write new ones.
- Terraform and Cloud Build deploy the app. `docker-compose.production.yml` and Traefik are not used for deployment.

| Generated file | Action |
|----------------|--------|
| `docker-compose.local.yml`, `docker-compose.docs.yml`, `compose/local/`, `.devcontainer/` | Keep. Unused locally. |
| `docker-compose.production.yml`, `compose/production/traefik/`, `compose/production/postgres/` | Keep as reference. Not used to deploy. |
| `compose/production/django/` (Dockerfile, `start`, Celery scripts) | Adapt for the Cloud Run image (step 12). |
| `justfile` | Keep the compose recipes. Add the Celery recipes from step 9 and the Tailwind recipes from step 10. |

## Component toolbox (use the lightest tool that works)

Pick the first option in this list that meets the need. Move down only when the option above cannot do the job.

1. django-basecoat. Every UI element it ships a component for. This is the default for all UI.
2. django-cotton. Your own layouts and compositions of Basecoat components, such as the app shell, the nav, and page sections.
3. Alpine.js. Local UI state that never needs the server and that Basecoat does not already handle, such as the theme store and small toggles. Do not use Alpine to rebuild a Basecoat component.
4. django-unicorn. A component that needs server-side reactive state, such as a live-updating widget. It sends AJAX requests that return JSON, so it is a bounded exception to the "no JSON endpoints for UI" rule. Keep it inside the component and out of page navigation.
5. tetra (a full-stack component framework built on Alpine.js, called "terra" in conversation). Use it only on pages that need high interactivity. Do not use it for ordinary pages.

- Do not install django-unicorn or tetra in the skeleton. The home-page slice needs neither.
- Record each first use of option 4 or 5 in an AgDR with `/decide`. Write that file in the app repo at `docs/agdr/`.
- Put this ladder in the new repo's AGENTS.md.

## Process

### 0. Write the active-issue-skill marker (REQUIRED — me2resh/apexyard#268)

Before any `gh issue create` or other tracker CLI call, write this skill's name to the active-issue-skill marker. The `require-skill-for-issue-create.sh` hook then lets the command through.

```bash
ops_root="$PWD"; r="$PWD"
while [ "$r" != / ]; do
  if [ -f "$r/.apexyard-fork" ] || { [ -f "$r/onboarding.yaml" ] && [ -f "$r/apexyard.projects.yaml" ]; }; then
    ops_root="$r"; break
  fi
  r=${r%/*}
done
mkdir -p "$ops_root/.claude/session"
echo "walking-skeleton-django" > "$ops_root/.claude/session/active-issue-skill"
```

Remove the marker on **every** exit path: success, early exit, cancel, and error.

```bash
rm -f "$ops_root/.claude/session/active-issue-skill"
```

See AgDR-0030.

### 1. Collect the inputs

Parse `$ARGUMENTS` as `<app-name> — <purpose>`. Ask only for what is missing, as one batch.

| Input | Form |
|-------|------|
| App name | kebab-case. This is the repo name. |
| Django project slug | snake_case. Derive it from the app name and confirm it. |
| One-line purpose | One sentence. |
| GitHub owner and visibility | The user or org, and private or public. |
| Description | `description` option. Default to the one-line purpose and ask the operator to confirm or edit it. |
| Author name | `author_name` option. Offer `git config user.name` as the default. Never leave the template author. |
| Domain name | `domain_name` option, such as `example.com`. Always ask. There is no useful default. |
| Author email | `email` option. Offer `git config user.email` as the default. |
| License | `open_source_license` option: MIT, BSD, GPLv3, Apache Software License 2.0, or Not open source. Recommend MIT. |
| Username type | `username_type` option: `username` or `email`. Recommend `email`. |
| PostgreSQL version | `postgresql_version` option: 18, 17, 16, 15, or 14. Recommend the newest. The Terraform VM must run the same version. |
| Mail service | `mail_service` option: Mailgun, Amazon SES, Mailjet, Mandrill, Postmark, Sendgrid, Brevo, SparkPost, or Other SMTP. |
| REST API | `rest_api` option: None, DRF, or Django Ninja. Recommend None unless the purpose needs an API. |
| CI tool | `ci_tool` option: None, Travis, Gitlab, Github, or Drone. Recommend Github. |
| Default superuser | Whether the production start script creates a default superuser, and the local part of its email (default `admin`). The email becomes `<admin>@<domain_name>` using the domain from this table. Recommend yes. |
| GCP projects | The project id for `dev` and the project id for `prod`. Recommend two projects. Accept one project when the operator has one. Never invent a project id. If the ids are unknown, leave them empty. Say that in the report. |
| Cloud Build connection | The existing 2nd-gen connection name. Ask for it. Do not invent a name. |
| Region and zone | The GCP region and the database zone. Ask for both. Do not invent them. |
| SQLite for tests | Whether to hardcode the test database in `config/settings/test.py` to SQLite (step 9). Recommend yes, so tests need no Postgres. |

Ask for these in one batch. Give each question its recommended answer, so the operator can accept the defaults in one reply. Do not ask for anything that step 4 pins.

Do not write a project id into `cloudbuild.yaml` defaults.
The admin email is the superuser email from this table.
Pass the connection name, region, zone, project id, and admin email into the bootstrap script.

### 2. Verify the ticket prefix

Read `.ticket.prefix_whitelist` from `.claude/project-config.*.json`. The skeleton is a `[Feature]`-class ticket. If `Feature` is not in the list, stop. Tell the operator to add it, or to name the prefix the fork uses for delivery work.

### 3. Show the plan and the file tree

Resolve the workspace and docs paths. Show the planned repo path, the docs path, the cookiecutter options, and the planned file tree. Ask for a go before you generate anything.

### 4. Generate the project

1. Check that the cookiecutter CLI is installed. If it is not, search for the current install instructions. Install it the way the operator's tooling prefers. `uv tool install cookiecutter` is the usual route. Tell the operator what you installed.
   Then run `docker info`. If Docker is missing or its daemon is not running, stop. Tell the operator to start Docker before you generate. The cookiecutter hook needs it (see "Docker policy").
2. Run cookiecutter on `https://github.com/cookiecutter/cookiecutter-django` with `--no-input` and `--output-dir <workspace_dir>`. Pass every option below as `key=value`. Pass the operator's answers from step 1 for the asked options. Accept the template defaults for everything not listed.
   - From step 1: `project_name`, `project_slug`, `description`, `author_name`, `domain_name`, `email`, `open_source_license`, `username_type`, `postgresql_version`, `mail_service`, `rest_api`, `ci_tool`.
   - Pinned, never asked:
     - `use_docker=y`. Cookiecutter then generates the production Dockerfile, the production start scripts, and the justfile. Local work does not use Docker. See "Docker policy".
     - `use_async=y`. The app runs on ASGI.
     - `frontend_pipeline=None`. Tailwind v4 and Basecoat replace it.
     - `use_whitenoise=y`. Cloud Run serves static files from the container.
     - `debug=y`. This is the cookiecutter flag that enables debug tooling in the generated local settings. Production settings keep `DEBUG` off.
     - `use_celery=y`. Cookiecutter's Celery setup needs Redis as the broker, so keep Redis.
     - `cloud_provider=GCP`, so the generated settings use GCS for media through `django-storages`.
     - `editor=None`.
   - Keep the allauth setup that cookiecutter generates. Configure no social providers.
   - Cookiecutter has no prompt for the Python version or for Channels. Set Python 3.14 and install Django Channels yourself in step 9.
   - If the operator asks for `use_docker=n`, stop and confirm. Steps 9, 10, and 12 use the justfile and the production Docker files that only `use_docker=y` generates.
3. Cookiecutter names the directory after `project_slug`. Rename it to `<app-name>`.
   If cookiecutter created a `.venv`, delete it. The venv holds absolute paths that the rename breaks. Step 9 creates a new one.
4. Check that these generated files exist: `justfile`, `compose/production/django/Dockerfile`, `compose/production/django/start`, and `docker-compose.local.yml`. If one is missing, stop and ask the operator.
5. Make sure the generated project is a git repository. Run `git init` if cookiecutter did not. Use `main` as the default branch.
6. Before the first commit, check `git config --global user.name` and `git config --global user.email`. If either is empty, set both on this repo only, using the author name and email from step 1: `git config user.name` and `git config user.email`. Do not change the global config.
7. Make the first commit on `main` from the untouched cookiecutter output, with the message `chore: initial cookiecutter-django output`. Leave this commit unpushed. Step 6 pushes `main`.

### 5. Check the tools

Check that these tools are installed.
The tools are `uv`, `just`, `gh`, `gcloud`, `terraform`, the `tailwindcss` CLI, a Redis server, and `docker`.
Step 4 already checked that the Docker daemon runs.
Report what is missing.
Ask before you install anything on the operator's machine.

### 6. Create the GitHub repository

1. Show the exact `gh repo create <owner>/<app-name>` command with the visibility from the inputs. Wait for the operator's explicit go before you run it.
2. Create the repo empty: no README, no `.gitignore`, no license, and no `--source` or `--push` flag.
3. Add the remote with `git remote add origin <url>`. Verify it with `git remote -v`.
4. Push `main` to `origin` before step 8.
   Do not push any other branch.
   The ticket branch needs this base to open a PR.
5. Ask whether to link the repo to a GitHub Project. Wait for the answer.
   - On no, go on.
   - On yes, list the projects with `gh project list --owner <owner>`. Ask which one. Show the exact `gh project link <number> --owner <owner> --repo <owner>/<app-name>` command and wait for the go before you run it.
   - If the command fails because the token lacks the `project` scope, give the operator the `gh auth refresh -s project` command. Do not run it.
   - Record the project owner and number. Step 7 needs them. If the operator chose no project, step 7 skips the project fields and says so in the report.
6. Do not register the app yet. Registration is a write to the portfolio, so it waits for the ticket in step 8.

### 7. File the walking-skeleton ticket

The ticket lives in the new repo's issue tracker. The layers are fixed for this skill, so do not interview the operator for them.

Show the full ticket and ask for a yes before you create it:

```
**[Feature] Walking skeleton — {app-name}**

## User Story
As a team building {app-name} ({purpose}), I want the thinnest end-to-end
slice wired through every layer so that integration and architecture are
proven early and we build the product on top of it.

## Acceptance Criteria
- [ ] Every layer is exercised: browser (Basecoat, Cotton, Unpoly, Alpine)
      → Django view → Celery task through Redis → Postgres → GCP deploy path
- [ ] The home page renders from Basecoat components and follows the theme toggle
- [ ] A trivial Celery task has a test that runs it eagerly
- [ ] Django Channels is installed and registered (`INSTALLED_APPS`, ASGI router, Redis channel layer), and a trivial websocket consumer has a test
- [ ] `terraform fmt` and `terraform validate` pass for the full GCP stack in both `dev` and `prod`
- [ ] Cloud Build builds the image with Docker BuildKit, not Kaniko
- [ ] `gcloud builds submit` of the feature branch deploys `dev`
- [ ] The dev Cloud Run revision is Ready and migrations ran
- [ ] A push to `main` deploys to `dev`
- [ ] A `vX.Y.Z` release tag deploys to `prod` after trigger approval
- [ ] The slice's logic has tests with > 80% coverage (KEPT code, not
      spike-exempt) and passes Rex and the security gate

## In Scope (the wiring)
- cookiecutter-django project, local .venv, GitHub repo
- Basecoat / Cotton / Unpoly / Alpine / Tailwind frontend with dark mode
- Celery worker and beat, Django Channels, justfile recipes, Zed tasks
- release-please
- GCP Terraform for `dev` and `prod`. Cloud Build is the only apply. The bootstrap script submits the first `dev` deploy.

## Out of Scope (built later on the skeleton)
- Business features, real auth providers, email, monitoring and alerting
- Custom domain and managed TLS
- django-unicorn and tetra

## Glossary
| Term | Definition |
|------|------------|
| Walking skeleton | Thinnest end-to-end slice exercising the whole architecture. It is kept and grown into the product. |
| Basecoat | The shadcn/ui design system without React, used here through django-basecoat. |
```

Labels: `enhancement`. Do not apply `spike`. There is no `walking-skeleton` exemption label.

#### Ticket metadata (show it with the ticket, and get it confirmed in the same yes)

Register every ticket this skill creates in the linked GitHub Project. Give each ticket this metadata. Show it next to the ticket body:

| Field | Value | Where it is set |
|-------|-------|-----------------|
| Project | The project from step 6 | `gh project item-add` |
| Status | `Ready` | Project field |
| Milestone | Default `Walking skeleton`. Reuse it if it exists. Create it if it does not. | The issue's milestone |
| Labels | `enhancement`, plus any label the operator names. Create a missing label before you apply it. | The issue |
| Size | Suggest `L`. Options are `XS`, `S`, `M`, `L`, `XL`. | Project `Size` field |
| Priority | Suggest `P0`. Options are `P0`, `P1`, `P2`. | Project `Priority` field |
| Start date | Today | Project `Start date` field |
| Target date (due date) | Ask the operator. There is no default. If the operator gives none, leave it empty and say so in the report. | Project `Target date` field, and the milestone due date |
| Dependencies | Ask which tickets block this one, or which this one blocks. For the first ticket in a repo the answer is none. | The issue's dependency links |

Never invent a date, a size, or a dependency. Ask one focused question for each value that is missing. Give a recommendation with each question.

Create the ticket through the tracker abstraction:

```bash
tracker_lib="$(r="$PWD"; while [ -n "$r" ] && [ "$r" != / ]; do \
  [ -f "$r/.claude/hooks/_lib-tracker.sh" ] && { echo "$r/.claude/hooks/_lib-tracker.sh"; break; }; \
  r="${r%/*}"; done)"
. "$tracker_lib"

body_file="$(mktemp)"
cat > "$body_file" <<'BODY'
{formatted body}
BODY

result="$(tracker_create "{owner/repo}" "[Feature] Walking skeleton — {app-name}" "$body_file" "enhancement")"
rc=$?
rm -f "$body_file"
if [ "$rc" -eq 3 ]; then
  echo "Tracker is 'none' (shape-only) — nothing was created in a tracker." >&2
  printf '%s\n' "$result"
  exit 0
elif [ "$rc" -ne 0 ] || [ -z "$result" ]; then
  echo "Ticket creation failed — check the tracker CLI and auth. Nothing was created." >&2
  exit 1
fi

ref="$(printf '%s' "$result" | jq -r '.ref')"
url="$(printf '%s' "$result" | jq -r '.url')"
```

If the tracker is `none`, the script stops after it prints the ticket. Tell the operator to file the ticket in the external tracker. Continue from step 8 only after the operator gives you the ticket number.

#### 7b. Register the ticket in the project and set its metadata

Run this right after the ticket exists. Use plain `gh` commands with an explicit `--repo` or `--owner` on each. Run them one at a time, so a failure names the step that failed.

1. Milestone. List all milestones with `gh api "repos/<owner>/<app-name>/milestones?state=all" --paginate`. If a milestone with the chosen title exists and has no due date, ask the operator before you set one. If the title is missing, create it with `gh api repos/<owner>/<app-name>/milestones -f title="<title>" -f due_on="<target date>T12:00:00Z"`. Use noon UTC, because GitHub shows a midnight UTC date as the previous day in timezones behind UTC. Omit `due_on` when there is no target date. Then run `gh issue edit <ref> --repo <owner>/<app-name> --milestone "<title>"`.
2. Labels. Check each label with `gh label list --repo <owner>/<app-name> --limit 200`. Create a missing one with `gh label create "<label>" --repo <owner>/<app-name>`. Apply it with `gh issue edit <ref> --repo <owner>/<app-name> --add-label "<label>"`.
3. Project item. Run `gh project item-add <number> --owner <owner> --url <issue url> --format json`. Keep the returned item `id`. Run `gh project view <number> --owner <owner> --format json` for the project `id`.
4. Project fields. Run `gh project field-list <number> --owner <owner> --format json` for the field and option ids. Never guess an id. If the project lacks a field or an option, skip that field and report it. Do not create project fields. Set each field with `gh project item-edit --id <item id> --project-id <project id> --field-id <field id> ...`:
   - `Status`, `Size`, and `Priority` use `--single-select-option-id <option id>`.
   - `Start date` and `Target date` use `--date YYYY-MM-DD`.
5. Dependencies. Link each ticket that blocks this one. For each blocking ticket, read its numeric id with `gh api repos/<owner>/<repo>/issues/<n> --jq .id`. Then run `gh api -X POST repos/<owner>/<app-name>/issues/<ref>/dependencies/blocked_by -F issue_id=<id>`. For a ticket that this one blocks, run the same call on that ticket's number with this ticket's id. If the API rejects a call, add a `Blocked by <owner>/<repo>#<n>` line to the ticket body. Report that the native link failed.
6. Verify. Read the item back with `gh project item-list <number> --owner <owner> --format json --limit 200`. Check that the milestone, labels, size, priority, status, and dates match what the operator confirmed. Read the dependency links back with `gh api repos/<owner>/<app-name>/issues/<ref>/dependencies/blocked_by`. Report any field that does not match. Do not report a field as set until you have read it back.

If the `project` token scope is missing, give the operator `gh auth refresh -s project`. Do not run it. The ticket stays filed. Report which fields are still unset.

### 8. Start the ticket and branch

1. Run `/start-ticket {owner/repo}#${ref}`.
2. In the new repo, create the branch `feature/GH-${ref}-walking-skeleton`.
3. Register the app in the registry file at `$registry` (resolved in the path section). Do this now, with the ticket active, so the ticket-first hooks and the portfolio skills see the app.
4. Do all remaining work on this branch.

Put the PRD and designs in `<projects_dir>/<app-name>/docs/`.
If the operator wants a PRD, use `/write-spec` there.
Write each AgDR in the app repo at `docs/agdr/`.
Do not write an app AgDR in the portfolio.

### 9. Local environment and cleanup

- Run `uv venv` and activate `.venv`. Use no Docker for local development. Leave the generated compose files in place (see "Docker policy").
- Run `uv run pre-commit install` so commits run the hooks.
- Set the `USE_DOCKER` default to False in `config/settings/local.py` with `env("USE_DOCKER", default=False)`.
- Switch off `ATOMIC_REQUESTS`.
- Fix `{project_slug}/contrib/sites/migrations/0003_set_site_domain_and_name.py` to work with SQLite. The `if created` block becomes `if created and not is_sqlite:`. Detect SQLite from the database engine in the normal way.
- Remove `python-slugify`, `django-crispy-forms`, and `crispy-bootstrap5` from the dependencies and from `base.py`.
- Create a sample `.env`. Include `DATABASE_URL` and `REDIS_URL` for the Celery broker.
- Local development has no Docker, so Redis runs on the host. Set `REDIS_URL` to the local Redis in the sample `.env`. Put the command to start Redis in the final report and in the README.
- Keep the Celery worker and beat running through new justfile recipes that call `uv run celery` directly. Do not use the compose recipes for them.
- If the operator chose SQLite for tests, hardcode the test database in `config/settings/test.py`. Place this block after the existing imports and settings. It replaces any `DATABASES` the file inherits:

  ```python
  DATABASES = {
      "default": {
          "ENGINE": "django.db.backends.sqlite3",
          "NAME": BASE_DIR / "db.sqlite3",
      },
  }
  ```

  `BASE_DIR` arrives through the star import from `base.py`, so ruff reports F405. Do not add `# noqa`. Import `BASE_DIR` explicitly (`from .base import BASE_DIR`) or use the ruff per-file-ignore the generated config already supports. Make sure `db.sqlite3` is git-ignored.
- Install Django Channels. Cookiecutter does not add it, so wire it by hand:
  - Add `channels` and `channels-redis` with `uv add`.
  - Add `"channels"` to `THIRD_PARTY_APPS` in `config/settings/base.py`.
  - Set `ASGI_APPLICATION = "config.asgi.application"` if the generated settings do not already.
  - Rewrite `config/asgi.py` so it returns a `ProtocolTypeRouter`. The `"http"` entry is the existing Django ASGI app. The `"websocket"` entry is an `AllowedHostsOriginValidator` around an `AuthMiddlewareStack` around a `URLRouter`. Keep the generated `sys.path` and settings-module lines.
  - Put the websocket routes in `<project_slug>/routing.py`. Put consumers in `<project_slug>/consumers.py`.
  - Set `CHANNEL_LAYERS` in `base.py` to `channels_redis.core.RedisChannelLayer`, with `hosts` read from `REDIS_URL`. Override it with `channels.layers.InMemoryChannelLayer` in `config/settings/test.py`, so tests need no Redis.
  - Keep Channels out of the Celery wiring. Celery stays the task queue and Channels stays the websocket layer. They share the one Redis, but use different keys.
  - Record the dependency choice in an AgDR with `/decide`. Write that file in the app repo at `docs/agdr/`.
- Do not create a Postgres role or database by hand.
  The startup script creates both on the database VM.
  Run the skeleton check against SQLite with `DATABASE_URL=sqlite:///db.sqlite3`.
  Run the tests against SQLite too.
  Use the hardcoded test settings when the operator chose them.
  Otherwise use the same `DATABASE_URL`.
  Tests run Celery tasks eagerly, so they need no Redis.

### 10. Add the frontend stack

- Install django-cotton and django-basecoat. Add `django_cotton` and `django_basecoat` to `INSTALLED_APPS`. Wire Basecoat's CSS and JavaScript as the django-basecoat README describes.
- Cookiecutter already generates a justfile. Edit that file. Do not create a new one or replace it.
- Add two Tailwind recipes to the justfile:
  - `tailwind-build` runs `tailwindcss -i ./src/css/tailwind.css -o ./<project_slug>/static/css/tailwind.css --minify`.
  - `tailwind-watch` runs the same command with `--watch --minify`.
- Keep the generated docker compose recipes in the justfile. Add the new recipes beside them.
- Commit the generated `tailwind.css`. Rebuild it after every template or CSS change. Add a CI step that rebuilds it and fails if the committed file is stale.

### 11. Add release-please

- Add `release-please-config.json`, `.release-please-manifest.json`, and a GitHub Actions workflow.
- Use release-type `python`.
- Add `uv.lock` as an `extra-files` entry of type `toml`, so the project version in the lockfile is bumped with each release. Use the jsonpath `$.package[?(@.name.value=='<app-name>')].version`.
- Start the manifest at the version the project is generated with.
- Set `"include-component-in-tag": false`, so release tags are plain `vX.Y.Z`. The production deploy trigger in step 12 matches that tag shape.

### 12. Add Terraform

Add Terraform under `infra/`.
It replaces `docker-compose.production.yml` for deployment.
Cloud Build is the only `terraform apply`.
On the laptop, run `terraform fmt` and `terraform validate` only.

- Target GCP.
  Pin the Google provider.
  The build installs Terraform 1.9.8.
- Declare inputs as variables.
  Write no secrets in any file.
- Use two environments, `dev` and `prod`.
  - `dev` deploys on every push to `main`.
  - `prod` deploys when release-please pushes a `vX.Y.Z` tag.
  - Put modules under `infra/modules/`.
    Use `apis`, `network`, `registry`, `build`, `database`, `storage`, `secrets`, and `run`.
  - Put no environment-specific values in the modules.
  - Add root modules at `infra/envs/dev/` and `infra/envs/prod/`.
  - Each root module wires the same modules.
  - Give each root module a `terraform.tfvars` file, an `environment` variable, a project id variable, and a state prefix.
  - Write no secrets in `terraform.tfvars`.
  - The two environments share no state.
    A change to `dev` must not touch `prod`.
  - Use the same small sizes for both environments unless the operator asks for a larger prod.
- Recommend two GCP projects.
  Accept one project when that is what the operator has.
- When `dev` and `prod` share one project, record the limit in the AgDR.
  The `dev` build account can read `prod` secrets.
- Keep the state prefixes `dev` and `prod`.
- Give `dev` and `prod` different subnet CIDRs when they share a project.
  Use `10.10.0.0/24` for `dev` and `10.20.0.0/24` for `prod`.
- Add a `backend "gcs"` block in each root module.
  Set `prefix` to the environment name.
  Do not set the bucket name in the committed backend.
- `infra/apply.sh` creates `gs://<project>-<app>-tfstate` when the bucket is missing.
  It then runs `terraform init -input=false -backend-config="bucket=<bucket>"`.
- Do not tell the operator to create the state bucket.

**Apply script.** Add `infra/apply.sh`.
It accepts `infra` or `services`.
Cloud Build runs it.
Do not run it on the laptop.

- `cloud-sdk:slim` does not contain Terraform.
  Install Terraform 1.9.8 in the build before `terraform init`.
- Pass `-lock-timeout=5m` on every apply.
- Pass `_CLOUDBUILD_REPOSITORY=none`.
  Terraform must not create a second trigger.
- The trigger resource depends on Cloud Run names.
  Those names do not exist during the infra phase.
- Import the build account before the first targeted apply.
  Do this when bootstrap already created the account and state does not contain it.
- Do not print secret values, database URLs, or Redis URLs.

**Infra phase.** Apply targets in this order.
Do not create Cloud Run in this phase.

1. Apply the API module and the secret containers.
   Include the database URL secret and the Redis URL secret.
   Add their versions after the database address is known.
2. Generate a secret version when none exists.
   Generate the Django secret, the database password, the Redis password, and the superuser password.
3. Apply the network module and the database module.
4. Wait until the data-disk Postgres accepts connections.
   Do not start the services phase before that wait succeeds.
5. Write the database URL secret from the database internal IP.
   Write the Redis URL secret from that IP and the Redis password.
   Replace either secret when its value changed.
6. Apply the registry, the build account, the runtime accounts, the secret IAM bindings, and storage.

- Secret ids are static strings, such as `<app>-<env>-django-secret-key`.
  A fresh state fails when a `for_each` key is unknown.
- The build account `act_as_runtime` map uses static keys.
  Use the keys `django`, `worker`, and `beat`.
  Do not use a resource attribute as a `for_each` key.
- The database password secret is write-once.
  Generate it before the instance boots.
  Do not add a second version in this skill.
- `POSTGRES_HOST` and `DATABASE_URL` share one source.
  That source is the database internal IP.
- The entrypoint waits on `POSTGRES_HOST`.
  Django migrates through `DATABASE_URL`.
  The host in those two values must match.
- Rewrite the database URL secret when the VM address changes.

**Services phase.** Run `infra/apply.sh services` with `_IMAGE` set to the pushed image.
The script exits if `_IMAGE` is empty.
Create the Cloud Run service and both worker pools only in this phase.
The service depends on its secret IAM bindings.
Every referenced secret needs a version before this phase.

**Container image.**

- Adapt the files in `compose/production/django/`.
  Change only what Cloud Run needs.
  List each change in the final report.
- The Django service, the Celery worker, and Celery beat use one image.
  Only the command differs.
- Keep the Dockerfile `RUN --mount=type=bind` lines for `uv.lock` and `pyproject.toml`.
- Add `CMD ["/start"]` after the `ENTRYPOINT` when the Dockerfile has no `CMD`.
- The worker command is `/start-celeryworker`.
  The beat command is `/start-celerybeat`.
- Do not build with Kaniko.
  Kaniko cannot see those bind-mounted files, so the build exits.
- Build with Docker BuildKit.
  Use the builder `gcr.io/cloud-builders/docker`.
  Set `DOCKER_BUILDKIT=1`.
- Do not return to Kaniko unless the Dockerfile drops those mounts.
- Do not default the image to `us-docker.pkg.dev/cloudrun/container/hello`.
  That image has no `/start-celerybeat`.
- Give the image variable no default.
  The services phase sets it.
- Tag the image with the commit SHA.
  Push that tag.
  The image path is `<region>-docker.pkg.dev/<project>/<app>-<env>/<app>:<short-sha>`.

**Start script.** Keep the generated gunicorn command.
Change the bind to `0.0.0.0:${PORT:-8080}`.
After `collectstatic`, take advisory lock `728194`.
Run `migrate` while that lock is held.
Then release the lock.
Hold the lock in the Django session.
Run `migrate` in a child process.
Postgres releases the lock when that session ends.
The start script is the only migration path.
Do not add a migrate job.
Create the superuser only when `DJANGO_DEFAULT_SUPERUSER_PASSWORD` is set.
The build generates that secret.
The operator does not type it.
Use no fallback password.
If `username_type` is `username`, match the user model in the lookup and in `createsuperuser`.
Tell the operator to change the password after the first login.
Replace `[[admin]]` and `[[domain]]` when you write the file.
Do not leave those placeholders in the app repo.

```bash
python /app/manage.py shell --no-imports <<'LOCK'
import subprocess

from django.db import connection

LOCK_ID = 728194

with connection.cursor() as cursor:
    cursor.execute("SELECT pg_advisory_lock(%s)", [LOCK_ID])
try:
    subprocess.check_call(["python", "/app/manage.py", "migrate", "--noinput"])
finally:
    with connection.cursor() as cursor:
        cursor.execute("SELECT pg_advisory_unlock(%s)", [LOCK_ID])
LOCK

if [ -n "${DJANGO_DEFAULT_SUPERUSER_PASSWORD:-}" ]; then
  SUPERUSER_EXISTS=$(echo "from django.contrib.auth import get_user_model;User=get_user_model();print(User.objects.filter(email=\"${DJANGO_DEFAULT_SUPERUSER_USERNAME:-[[admin]]@[[domain]]}\").count())" | python /app/manage.py shell --no-imports)
  test $SUPERUSER_EXISTS == 0 && DJANGO_SUPERUSER_PASSWORD="${DJANGO_DEFAULT_SUPERUSER_PASSWORD}" python /app/manage.py createsuperuser --email ${DJANGO_DEFAULT_SUPERUSER_USERNAME:-[[admin]]@[[domain]]} --noinput || true
fi
```

Record the migrate race and this lock in the AgDR.

**Entrypoint.** Keep the generated entrypoint.
It uses `set -o nounset`.
Set `POSTGRES_USER`, `POSTGRES_HOST`, and `POSTGRES_PORT` on every workload.
`POSTGRES_PORT` is `5432`.
`POSTGRES_USER` is the database user in `DATABASE_URL`.
`POSTGRES_HOST` is the same IP as the host in `DATABASE_URL`.
`wait-for-it` is not a readiness gate.
A first boot that is still installing packages outlasts that wait.

**Database startup script.** The database VM runs the same Postgres version as step 1.

- Use `set -euo pipefail`.
  Never use `set -x`.
- The script reads the metadata token, the database password, and the Redis password.
  Do not put those values in a traced command.
  Do not print them.
- Stop the packaged `postgresql` service before `pg_ctl`.
  Then disable that service.
- The Debian package binds port 5432.
  The data-disk server must bind that port.
- The script creates the database role and the database.
  Do not tell the operator to create either one.
- A metadata change does not rerun the startup script until the next boot.
  The first boot must be correct.
- After `pg_isready` succeeds on the data-disk server, print one ready line.
- `infra/apply.sh` polls the serial port for that line.
  Fail the infra phase if the line does not appear.
  Do not print the serial port output.

**Build file.** Add one `cloudbuild.yaml` for both environments.

- Do not default `_PROJECT_ID`.
  You may default `_ENV` to `dev` and `_CLOUDBUILD_REPOSITORY` to `none`.
- Pass `_PROJECT_ID`, `_REGION`, and `_ENV` from the trigger and from `gcloud builds submit`.
- Set logging to `CLOUD_LOGGING_ONLY`.
- Use four steps: infra apply, image build, image push, then services apply.
- Each apply step uses `gcr.io/google.com/cloudsdktool/cloud-sdk:slim`.
  Install Terraform 1.9.8 in that step.
- The build step uses `gcr.io/cloud-builders/docker` with `DOCKER_BUILDKIT=1`.
- Set `timeout: 1800s`.
  That covers the image build and the first database boot.
- A trigger supplies `SHORT_SHA`.
  `gcloud builds submit` does not.
  Pass `SHORT_SHA` on the submit command.

**Bootstrap.** Add `bin/bootstrap-cloud-build.sh`.
Write it in this step.
Run it in step 15.
It runs once from the laptop.
It does not run Terraform.

Use the connection name, region, zone, project id, and admin email from step 1.
Do not hardcode a project id.

The script does this:

1. Enable Cloud Build, Resource Manager, and IAM.
2. Create `<prefix>-dev-build` and `<prefix>-prod-build`.
   Derive `<prefix>` from the app name.
   Keep each account id between 6 and 30 characters.
   Do not reuse another app's build account.
3. Grant each build account these roles:
   - `roles/editor`
   - `roles/iam.securityAdmin`
   - `roles/iam.serviceAccountAdmin`
   - `roles/serviceusage.serviceUsageAdmin`
   - `roles/secretmanager.admin`
   - `roles/artifactregistry.admin`
   - `roles/logging.logWriter`
4. Do not grant those roles to the default Cloud Build account.
5. Grant `roles/iam.serviceAccountUser` on each build account to the Cloud Build service agent.
   The agent is `service-<projectNumber>@gcp-sa-cloudbuild.iam.gserviceaccount.com`.
6. Grant that same role on each build account to the user who submits.
7. Link the GitHub repository with `gcloud builds repositories create`.
   Pass `--connection`, `--region`, and `--remote-uri`.
8. Create triggers with `--repository` and `--region`.
   Do not use the 1st-gen `--repo-name` flag.
   That API fails with `Repository mapping does not exist`.
9. The connection login is a human step.
   The repository link is not.
   If the connection does not exist, stop.
   Ask the operator to finish that login.
   Do not link the repository in the console.
10. Create the `dev` trigger on `^main$`.
    Do not require approval.
11. Create the `prod` trigger on `^v[0-9]+\.[0-9]+\.[0-9]+$`.
    Pass `--require-approval` on create.
12. Do not call `gcloud builds triggers update github --require-approval`.
    That command returns `INVALID_ARGUMENT` on this 2nd-gen trigger.
13. If the prod trigger exists and approval is already true, leave it.
14. If approval is not true, delete the trigger and create it again.
15. Submit the current feature-branch commit with `gcloud builds submit` and the `dev` build account.
    Pass `_CLOUDBUILD_REPOSITORY=none` and `SHORT_SHA`.
16. The `dev` trigger cannot deploy a feature branch.
    It listens only to `main`.
17. Pushing `main` is not this proof.

On a retry, submit the build again.
Do not run the IAM grants again.
Before a submit, check for a build in status `WORKING`.
If one exists, wait.
Do not submit a second build.

**Cloud Run.**

- Add one Cloud Run service for Django.
- Add one worker pool for the Celery worker.
- Add one worker pool for Celery beat, with exactly one instance.
- Set `deletion_protection = false` on the service and on both pools.
- Set `launch_stage = "BETA"` on both worker pools.
- `ignore_changes` lists `client` and `client_version` only.
  Do not ignore the container image.
- Grant `allUsers` the role `roles/run.invoker`.
  Say in the report that an organization policy can still return 403.
- Set `DJANGO_ALLOWED_HOSTS` so the value includes `.run.app` and the app domain.
- Give each workload its own service account.
  Grant only the access that workload needs.
- Read the current provider docs for the worker pool resource.
  Pin a provider version that supports it.
- Store `DJANGO_SECRET_KEY`, `DATABASE_URL`, `REDIS_URL`, and `DJANGO_DEFAULT_SUPERUSER_PASSWORD` in Secret Manager.
  Pass each one as a secret reference.
- Pass `POSTGRES_HOST`, `POSTGRES_PORT`, and `POSTGRES_USER` as plain environment variables.
- Runtime account ids use the same prefix as the build accounts.
  Use `<prefix>-<env>-web`, `<prefix>-<env>-worker`, `<prefix>-<env>-beat`, and `<prefix>-<env>-db`.

**Database host.** One small Compute Engine instance runs Postgres and Redis.

- Give the instance no public IP.
  Use a separate persistent disk for data.
- The startup script installs Postgres and Redis.
  Require a password for Redis.
- Add a daily snapshot schedule for the data disk.
  Add a nightly `pg_dump` to a backup bucket.

**Networking.**

- Create a VPC and a subnet.
  Connect Cloud Run with Direct VPC egress.
- Use a Serverless VPC Access connector only when Direct VPC egress does not fit.
- Allow port `5432` and port `6379` only from the Cloud Run subnet.
- Allow SSH only through IAP.
  Add Cloud NAT for outbound traffic from the instance.

**Storage.** Add one media bucket with uniform bucket-level access.
Give only the Django service account access to that bucket.
Configure Django to use it through `django-storages`.

**Registry.** Add one Artifact Registry Docker repository.
Add a cleanup policy that deletes untagged images.
Do not add a Kaniko cache repository.

**AgDR.** Write the deploy record in the app repo at `docs/agdr/`.

- Record that Cloud Build is the only `terraform apply`.
  A laptop apply is not the deploy path.
- Record Docker BuildKit, not Kaniko, and the bind-mount reason.
- Record the two roots and the separate state prefixes.
  When both environments share one project, record that the `dev` build account can read `prod` secrets.
- Record that the prod trigger requires approval.
  Record delete-and-create when approval is off.
  Do not record the update command.
- Record that the connection login is manual.
  Record that the repository link is not.
- An AgDR that still requires Kaniko or a laptop apply is wrong.
  Change the record so it matches this path.

**Release tags.** Check that a release-please tag still starts the prod trigger.
Release-please creates the tag through the GitHub API.
If the Cloud Build connection misses that tag, say so in the report.

**Outputs.** Add outputs for the Cloud Run URL, the registry path, and the media bucket name.

**Checks.** Run `terraform fmt`.
Run `terraform validate` in `infra/envs/dev/` and in `infra/envs/prod/`.
Do not run `terraform apply`.

### 13. Add Zed tasks

Add `.zed/tasks.json` so each local process starts from the Zed task picker. Make sure `.zed/` is not git-ignored, and commit the file.

- Give every task `"cwd": "$ZED_WORKTREE_ROOT"`, `"use_new_terminal": true`, `"reveal": "always"`, and `"hide": "never"`.
- Set `"allow_concurrent_runs": true` on the long-running tasks. Set it to false on the pytest task.
- Set `DJANGO_SETTINGS_MODULE` to `config.settings.local` and `DJANGO_READ_DOT_ENV_FILE` to `True` in `env` for every Django and Celery task.
- Add these tasks:
  - "Tailwind CSS Watch" runs `just tailwind-watch`.
  - "Django Server" runs `uv run python manage.py runserver 0.0.0.0:8881`. Use port 8881.
  - "uvicorn Server" runs `uv run uvicorn config.asgi:application --host 0.0.0.0 --port 8882 --reload`. This is the ASGI entrypoint and the only local server that serves websockets, because `runserver` does not run the Channels router without daphne. Use port 8882. The "Django Server" task uses 8881. Add `uvicorn` as a dev dependency with `uv add --dev uvicorn` if the generated project does not already include it.
  - "Celery Worker" runs `uv run celery -A config.celery_app worker --loglevel=info`.
  - "Celery Beat" runs `uv run celery -A config.celery_app beat --loglevel=info`.
  - "Run pytest" runs `uv run pytest --cov=<project_slug> --cov-report=html --cov-report=term`.
- Make the Zed tasks call the justfile recipes for the worker and beat that step 9 added.

### 14. Write AGENTS.md

Write an `AGENTS.md` in the new repo. It lists the stack, the architecture rules, the Basecoat component list, and the component toolbox above. It also lists these project rules:

- Never write migrations by hand. Generate them with `makemigrations`.
- Never use `# noqa`. Fix the cause of the lint error.
- Write no comments that narrate what the code does. Comment only non-obvious intent.
- Add no trailer lines to commit messages.
- Run `uv run pytest`, `uv run mypy <project_slug>`, and `pre-commit run --all-files` before every commit.
- Rebuild and commit `tailwind.css` after every template or CSS change.

### 15. Prove the skeleton works end to end

- Home page: a Basecoat button, card, and dropdown menu in one cotton component, plus one Tailwind class. One button opens `/welcome/` in one Unpoly modal, per the rules above. The theme toggle, Basecoat, and the modal follow the dark theme.
- Add one test for the page.
- Add a trivial Celery task named `ping`. Add a test that runs it eagerly.
- Add a trivial websocket consumer on `ws/ping/` that replies `pong`. Add a test that connects with `channels.testing.WebsocketCommunicator`, sends a message, and checks the reply. Use the in-memory channel layer. When you run the app, start it with the "uvicorn Server" task command so the websocket route is reachable.
- Run `pytest`, `mypy`, and `pre-commit`. Report the exact results.
- Run the app and check the page in a browser. If you cannot run a browser, say which criteria you could not verify there.
- Run `bin/bootstrap-cloud-build.sh` from the app repo.
  This is the first deploy proof.
- The proof is `gcloud builds submit` of the current feature-branch commit.
  Pushing `main` is not the proof.
- Do not ask for approval of the dev submit.
  The skill authorizes that submit.
- If `gcloud` is not authenticated, stop.
  Ask the operator to finish the `gcloud` login.
- If the GitHub connection does not exist, stop.
  Ask the operator to finish that login.
  Do not link the repository in the console.
- Do not submit while a build is `WORKING`.
- If the build fails, submit it again.
  Do not run the IAM grants again.
- After the build status is `SUCCESS`, read the Cloud Run URL.
- Confirm the revision is Ready.
  Confirm that migrations ran.
  Read the service logs for the migrate result.
- Do not print secret values, database URLs, or Redis URLs.
- Do not merge.
  Rex and an explicit human nod own the merge.

### 16. Report

Report in plain language. Lead with the outcome. Then give:

- The repo path, the branch, the ticket URL, and the GitHub repo URL.
- What is verified, with the command and the result.
- What is not verified, and why.
- The build id and status from `gcloud builds submit`.
  That submit is the first deploy proof.
  Pushing `main` is not the proof.
  Step 6 already pushed `main`.
- The Cloud Run URL when the build status is `SUCCESS`.
  State whether the revision is Ready and whether migrations ran.
- The manual steps left for the operator:
  - Finish the one-time `gcloud` login if it is still open.
  - Finish the GitHub connection login if the connection does not exist.
  - Approve the prod trigger when a prod release runs.
  - Push the feature branch.
    Do not push it to prove the dev deploy.
  - Start Redis locally.
  - Change the generated superuser password after the first login.
  - Merge only after Rex and an explicit human nod.
    Do not merge from this skill.

Remove the active-issue-skill marker.

Remind the operator that this is a KEPT skeleton and goes through the full SDLC. That means tests with > 80% coverage, Rex review, the security gate, and all merge gates. Build real features on top of the merged skeleton, one ticket at a time.

## Rules

1. **Ask when needed, never by reflex.** Do not re-ask what this skill decides. Ask one question at a time. The step 1 input batch is the one exception.
   If you change a pinned cookiecutter option, check every step that mentions it before you run.
2. **Confirm outward-facing actions.** The GitHub repo, the project link, and the ticket each need a yes.
3. **KEPT, not throwaway.** Do not apply the `spike` label or any exemption label.
4. **Push `main` once. Cloud Build applies.**
   Step 6 pushes `main` and no other branch.
   Do not push the feature branch.
   Do not run `terraform apply` on the laptop.
   Cloud Build is the only apply.
   The first proof is `gcloud builds submit` of the feature branch.
   Pushing `main` is not that proof.
5. **Use Basecoat first.** Never hand-roll a component that Basecoat ships.
6. **Do not install django-unicorn or tetra** in the skeleton.
7. **Register every ticket.** Add each ticket this skill creates to the linked GitHub Project. Set its milestone, labels, size, priority, dates, and dependencies (step 7b). Read the fields back before you report them as set.
8. **Branch name.** Always `feature/GH-<ticket>-walking-skeleton`.
9. **Report what is not verified.** Do not describe an unrun check as passed.
10. **Three human steps.** Keep the one-time `gcloud` and GitHub connection login.
    Keep prod trigger approval.
    Keep the merge gate.
    The merge needs Rex and an explicit human nod.
    Do not merge from this skill.
    Do not ask the operator to type secrets.
    Do not ask the operator to create the database or the state bucket.
    Do not ask the operator to link the repository in the console.
    Do not ask the operator to run the first deploy or the first `terraform apply`.

## Where this sits in the SDLC

A walking skeleton is Build-phase work like any feature. It carries no exemptions:

| Gate | Walking-skeleton work |
|------|------------------------|
| Pre-Build (ticket, ACs) | Required. The skeleton ticket carries the wiring ACs. |
| AgDR for technical decisions | Required. The skeleton makes the architecture decisions, so record them with `/decide`. The GCP topology and the database-on-a-VM choice are material. |
| Test coverage > 80% | Required. This is kept code. |
| Code Reviewer agent (Rex) | Required. |
| Security Auditor | Required for the Terraform, IAM, secrets, and network changes. |
| Glossary in PR body | Required. |
| QA Engineer verification | Required. |

See `.claude/skills/walking-skeleton/SKILL.md` for the generic form of this skill.

---

*Part of [ApexYard](https://github.com/me2resh/apexyard) — multi-project SDLC framework for Claude Code · MIT.*
