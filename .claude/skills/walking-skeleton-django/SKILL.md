---
name: walking-skeleton-django
description: Bootstrap a new Django app as a walking skeleton — cookiecutter-django, local .venv, GitHub repo, Basecoat/Cotton/Unpoly/Alpine/Tailwind frontend, Celery, release-please, Zed tasks, and GCP Terraform. KEPT and grown; full SDLC (NOT exempt like /spike).
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
- The app's **docs** (PRD, designs, AgDRs) go in `<projects_dir>/<app-name>/docs/`. They do not go in the repo and they do not go in `_inbox`.

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

When you ask, ask one focused question at a time. Give a recommended answer and the reason. Keep going on the parts that do not depend on the answer.

Show the plan and the planned file tree before you build. Report what is verified and what is not.

## Stack and architecture rules

Core model: the server owns the page and the client animates it. This is a hypermedia app that feels like an SPA. It is not an SPA.

- Django 6.x handles routing, ORM, auth, and business logic.
- django-basecoat is the UI library for the whole app. It is Basecoat (the shadcn/ui design system without React) as django-cotton components. Make full use of it.
  - Before you build any UI, read the django-basecoat README and its demo site (https://django-basecoat.ignacemaes.com/). List the components it ships. Record that list in the new repo's AGENTS.md.
  - Build every screen from Basecoat components: button, card, input, select, checkbox, dialog, dropdown menu, tabs, table, alert, badge, breadcrumb, avatar, accordion, and the rest of what it ships.
  - When a needed element has no django-basecoat component, use the Basecoat CSS classes directly. Wrap the result in a project cotton component in `templates/cotton/`.
  - Write a custom component only when neither Basecoat option exists. Never hand-roll a dropdown, dialog, select, or tabs.
  - Style the app through Basecoat's theme tokens. Do not add a second component library. Do not use Web Awesome.
  - Check that Basecoat's interactive components (dialog, dropdown, select) still work after an Unpoly fragment swap and inside an Unpoly layer. If one needs re-initialisation, do it in an `up.compiler()`.
- django-cotton 2.x provides server-side components with slots and props. Components live in `templates/cotton/` and stay presentational. Business logic stays in views and services.
- Unpoly 3.x handles navigation: fragment swaps and layers (modals). Use the `unpoly` pip package and its `UnpolyMiddleware` for `request.up`. Do not implement the Unpoly protocol yourself. Build small view mixins on top of `request.up` (form, layer, delete) in `unpoly_mixins.py`.
- Alpine.js 3.x handles local UI state. Re-initialise Alpine on `up:fragment:inserted`. Alpine is for state and Unpoly is for navigation. Do not cross the two.
- Tailwind CSS 4.x uses CSS-first configuration: `@theme {}`, no `tailwind.config.js`, no content array. Name tokens by function (`--color-surface`), not by colour.
- Render HTML on the server at every URL. Use one URL per fragment. Do not build JSON endpoints to feed UI.
- Initialise JavaScript with `up.compiler()` and return a cleanup function. Never use `DOMContentLoaded` for anything inside a fragment.
- Bake in dark mode from the first commit with a three-way toggle: system, light, dark.
  - Put `data-theme` on `<html>`.
  - Add a synchronous inline script before paint to prevent a flash of the wrong theme.
  - Keep the toggle state in an Alpine store persisted in localStorage. This also covers the logged-out pages.
  - Wire Tailwind with `@custom-variant dark (&:where([data-theme="dark"], [data-theme="dark"] *))`.
  - Set `color-scheme` on `:root` to match.
  - Make Basecoat follow the same theme. Check how Basecoat selects its dark palette. If it uses a different hook than `data-theme`, bridge the two with a custom variant or a token mapping.
- Use this folder layout: `templates/cotton/` (components, including a theme toggle), `templates/layouts/` (base, app, auth), `templates/partials/` (fragments), `templates/pages/`, `static/js/` (`app.js` and `compilers/`), `static/css/`, and `unpoly_mixins.py`.

## Component toolbox (use the lightest tool that works)

Pick the first option in this list that meets the need. Move down only when the option above cannot do the job.

1. django-basecoat. Every UI element it ships a component for. This is the default for all UI.
2. django-cotton. Your own layouts and compositions of Basecoat components, such as the app shell, the nav, and page sections.
3. Alpine.js. Local UI state that never needs the server and that Basecoat does not already handle, such as the theme store and small toggles. Do not use Alpine to rebuild a Basecoat component.
4. django-unicorn. A component that needs server-side reactive state, such as a live-updating widget. It sends AJAX requests that return JSON, so it is a bounded exception to the "no JSON endpoints for UI" rule. Keep it inside the component and out of page navigation.
5. tetra (a full-stack component framework built on Alpine.js, called "terra" in conversation). Use it only on pages that need high interactivity. Do not use it for ordinary pages.

- Do not install django-unicorn or tetra in the skeleton. The home-page slice needs neither.
- Record each first use of option 4 or 5 in an AgDR with `/decide`. Adding a dependency is a material decision.
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

Parse `$ARGUMENTS` as `<app-name> — <purpose>`. Ask only for what is missing, one question at a time.

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

Ask for these in one batch of focused questions, each with its recommended answer, so the operator can accept the defaults in one reply. Do not ask for anything the "Generate the project" step pins.

### 2. Verify the ticket prefix

Read `.ticket.prefix_whitelist` from `.claude/project-config.*.json`. The skeleton is a `[Feature]`-class ticket. If `Feature` is not in the list, stop and tell the operator to add it or to name the prefix the fork uses for delivery work.

### 3. Show the plan and the file tree

Resolve the workspace and docs paths. Show the planned repo path, the docs path, the cookiecutter options, and the planned file tree. Ask for a go before you generate anything.

### 4. Generate the project

1. Check that the cookiecutter CLI is installed. If it is not, search for the current install instructions for cookiecutter and install it in the way the operator's tooling prefers (`uv tool install cookiecutter` is the usual route). Tell the operator what you installed.
2. Run cookiecutter on `https://github.com/cookiecutter/cookiecutter-django` with `--no-input` and `--output-dir <workspace_dir>`. Pass every option below as `key=value`. Pass the operator's answers from step 1 for the asked options. Accept the template defaults for everything not listed.
   - From step 1: `project_name`, `project_slug`, `description`, `author_name`, `domain_name`, `email`, `open_source_license`, `username_type`, `postgresql_version`, `mail_service`, `rest_api`, `ci_tool`.
   - Pinned, never asked:
     - `use_docker=n`. Local work uses `.venv`, and Terraform replaces docker-compose. See the note below.
     - `use_async=y`. The app runs on ASGI.
     - `frontend_pipeline=None`. Tailwind v4 and Basecoat replace it.
     - `use_whitenoise=y`. Cloud Run serves static files from the container.
     - `debug=y`. This is the cookiecutter flag that enables debug tooling in the generated local settings. Production settings keep `DEBUG` off.
     - `use_celery=y`. Cookiecutter's Celery setup needs Redis as the broker, so keep Redis.
     - `cloud_provider=GCP`, so the generated settings use GCS for media through `django-storages`.
     - `editor=None`.
   - Keep the allauth setup that cookiecutter generates. Configure no social providers.
   - Cookiecutter has no prompt for the Python version or for Channels. Set Python 3.14 and install Django Channels yourself in step 9.
   - If the operator asked for `use_docker=y`, stop and confirm. The rest of this skill assumes `n`: it deletes Docker-compose files and writes its own Dockerfile.
3. Make sure the generated project is a git repository. Run `git init` if cookiecutter did not. Use `main` as the default branch.
4. Make the first commit on `main` from the untouched cookiecutter output, with the message `chore: initial cookiecutter-django output`. This commit stays local. The operator pushes it.

### 5. Check the tools

Check that these tools are installed: `uv`, `just`, `gh`, `terraform`, the `tailwindcss` CLI, and a Redis server. Report what is missing. Ask before you install anything on the operator's machine.

### 6. Create the GitHub repository

1. Show the exact `gh repo create <owner>/<app-name>` command with the visibility from the inputs. Wait for the operator's explicit go before you run it.
2. Create the repo empty: no README, no `.gitignore`, no license, and no `--source` or `--push` flag.
3. Add the remote with `git remote add origin <url>`. Verify it with `git remote -v`.
4. Do not push. Leave the push for the operator.
5. Ask whether to link the repo to a GitHub Project. Wait for the answer.
   - On no, go on.
   - On yes, list the projects with `gh project list --owner <owner>`. Ask which one. Show the exact `gh project link <number> --owner <owner> --repo <owner>/<app-name>` command and wait for the go before you run it.
   - If the command fails because the token lacks the `project` scope, give the operator the `gh auth refresh -s project` command. Do not run it.
6. Register the app in the registry (`apexyard.projects.yaml`) so the ticket-first hooks and the portfolio skills see it.

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
- [ ] `terraform fmt` and `terraform validate` pass for the full GCP stack
- [ ] The Docker image builds through Cloud Build and kaniko
- [ ] The operator performs the first deploy and a smoke test passes against
      the live Cloud Run URL
- [ ] The slice's logic has tests with > 80% coverage (KEPT code, not
      spike-exempt) and passes Rex and the security gate

## In Scope (the wiring)
- cookiecutter-django project, local .venv, GitHub repo
- Basecoat / Cotton / Unpoly / Alpine / Tailwind frontend with dark mode
- Celery worker and beat, Django Channels, justfile recipes, Zed tasks
- release-please
- GCP Terraform: build, registry, Cloud Run, database host, network, media bucket

## Out of Scope (built later on the skeleton)
- Business features, real auth providers, email, monitoring and alerting
- Custom domain and managed TLS
- Separate dev and prod environments
- django-unicorn and tetra

## Glossary
| Term | Definition |
|------|------------|
| Walking skeleton | Thinnest end-to-end slice exercising the whole architecture. It is kept and grown into the product. |
| Basecoat | The shadcn/ui design system without React, used here through django-basecoat. |
| Cloud Run worker pool | A Cloud Run resource type for non-HTTP workloads such as a Celery worker. |
```

Labels: `enhancement`. Do not apply `spike`. There is no `walking-skeleton` exemption label.

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
elif [ "$rc" -ne 0 ] || [ -z "$result" ]; then
  echo "Ticket creation failed — check the tracker CLI and auth. Nothing was created." >&2
  exit 1
fi

ref="$(printf '%s' "$result" | jq -r '.ref')"
url="$(printf '%s' "$result" | jq -r '.url')"
```

### 8. Start the ticket and branch

1. Run `/start-ticket {owner/repo}#${ref}`.
2. In the new repo, create the branch `feature/GH-${ref}-walking-skeleton`.
3. Do all remaining work on this branch.

Put the app's docs in `<projects_dir>/<app-name>/docs/`. If the operator wants a PRD or an AgDR, use `/write-spec` or `/decide` there.

### 9. Local environment and cleanup

- Run `uv venv` and activate `.venv`. Use no Docker for local development.
- Set the `USE_DOCKER` default to False in `config/settings/local.py` with `env("USE_DOCKER", default=False)`.
- Switch off `ATOMIC_REQUESTS`.
- Fix `{project_slug}/contrib/sites/migrations/0003_set_site_domain_and_name.py` to work with SQLite. The `if created` block becomes `if created and not is_sqlite:`. Detect SQLite from the database engine in the normal way.
- Remove `python-slugify`, `django-crispy-forms`, and `crispy-bootstrap5` from the dependencies and from `base.py`.
- Create a sample `.env`. Include `DATABASE_URL` and `REDIS_URL` for the Celery broker.
- Local development has no Docker, so Redis runs on the host. Set `REDIS_URL` to the local Redis in the sample `.env`. Put the command to start Redis in the final report and in the README.
- Keep the Celery worker and beat running through justfile recipes, not docker compose.
- Install Django Channels. Cookiecutter does not add it, so wire it by hand:
  - Add `channels` and `channels-redis` with `uv add`.
  - Add `"channels"` to `THIRD_PARTY_APPS` in `config/settings/base.py`.
  - Set `ASGI_APPLICATION = "config.asgi.application"` if the generated settings do not already.
  - Rewrite `config/asgi.py` so it returns a `ProtocolTypeRouter`. The `"http"` entry is the existing Django ASGI app. The `"websocket"` entry is an `AllowedHostsOriginValidator` around an `AuthMiddlewareStack` around a `URLRouter`. Keep the generated `sys.path` and settings-module lines.
  - Put the websocket routes in `<project_slug>/routing.py`. Put consumers in `<project_slug>/consumers.py`.
  - Set `CHANNEL_LAYERS` in `base.py` to `channels_redis.core.RedisChannelLayer`, with `hosts` read from `REDIS_URL`. Override it with `channels.layers.InMemoryChannelLayer` in `config/settings/test.py`, so tests need no Redis.
  - Keep Channels out of the Celery wiring. Celery stays the task queue and Channels stays the websocket layer. They share the one Redis, but use different keys.
  - Record the dependency choice in an AgDR with `/decide`. Adding a dependency is a material decision.
- Do not create the Postgres database. Put the exact command in the final report. Run the tests and the skeleton check against SQLite with `DATABASE_URL=sqlite:///db.sqlite3`. Tests run Celery tasks eagerly, so they need no Redis.

### 10. Add the frontend stack

- Install django-cotton and django-basecoat. Add `django_cotton` and `django_basecoat` to `INSTALLED_APPS`. Wire Basecoat's CSS and JavaScript as the django-basecoat README describes.
- Cookiecutter already generates a justfile. Edit that file. Do not create a new one or replace it.
- Add two Tailwind recipes to the justfile:
  - `tailwind-build` runs `tailwindcss -i ./src/css/tailwind.css -o ./<project_slug>/static/css/tailwind.css --minify`.
  - `tailwind-watch` runs the same command with `--watch --minify`.
- Remove any docker compose recipes from the justfile. List what you removed in the final report. Terraform replaces docker-compose in this project.
- Commit the generated `tailwind.css`. Rebuild it after every template or CSS change. Add a CI step that rebuilds it and fails if the committed file is stale.

### 11. Add release-please

- Add `release-please-config.json`, `.release-please-manifest.json`, and a GitHub Actions workflow.
- Use release-type `python`.
- Add `uv.lock` as an `extra-files` entry of type `toml`, so the project version in the lockfile is bumped with each release. Use the jsonpath `$.package[?(@.name.value=='<app-name>')].version`.
- Start the manifest at the version the project is generated with.

### 12. Add Terraform

Add Terraform in an `infra/` directory in place of docker-compose.

- Target GCP. Pin the provider and Terraform versions. Declare inputs as variables. Write no secrets in any file.
- Split the code into modules under `infra/modules/`: apis, network, registry, build, database, storage, secrets, and run. Use one root module that wires them together.
- Add a backend block for remote state in a GCS bucket, with the bucket name as a variable. The state bucket is created outside this Terraform code. Say how to create it in the README.
- Enable the needed Google APIs with `google_project_service`: Cloud Run, Cloud Build, Artifact Registry, Compute Engine, Secret Manager, and IAM.
- **Container image.**
  - Cookiecutter does not generate a Dockerfile when `use_docker=n`. Write one production Dockerfile that installs dependencies with `uv`, runs `collectstatic`, and serves the ASGI app (`use_async=y`) with gunicorn and the uvicorn worker class, the way the generated production settings document it.
  - The Django service, the Celery worker, and Celery beat all use this one image. They differ only in the start command.
- **Build and registry.**
  - Artifact Registry: one Docker repository for the app images.
  - Add a cleanup policy that deletes untagged images.
  - Add `cloudbuild.yaml` that builds the image with kaniko and its layer cache, then pushes it to Artifact Registry. Tag each image with the commit SHA.
  - Kaniko writes its cache as tagged images, so the untagged-image policy will not remove it. Give the cache its own repository or path, with an age-based cleanup policy.
  - Check that the kaniko executor image you choose is still published and maintained. If it is not, tell the operator before you pick a replacement.
  - Add a Cloud Build trigger for pushes to `main`, and a service account for Cloud Build with only the roles it needs.
- **Cloud Run workloads.**
  - A Cloud Run service for the Django app.
  - A Cloud Run worker pool for the Celery worker.
  - A Cloud Run worker pool for Celery beat, fixed at exactly one instance.
  - A Cloud Run job that runs `manage.py migrate`.
  - Give each workload its own service account with least privilege.
  - Check the current Terraform provider docs for the worker pool resource. Check that the provider version you pin supports it.
- **Database host.** One small Compute Engine instance that runs Postgres and Redis.
  - No public IP. Use a separate persistent data disk for Postgres data.
  - Provision Postgres and Redis with a startup script. Require a password for Redis.
  - Add a snapshot schedule for the data disk and a nightly `pg_dump` to a GCS backup bucket.
- **Networking between Cloud Run and the instance.**
  - Create a VPC and a subnet. Connect Cloud Run through Direct VPC egress. Use a Serverless VPC Access connector only if Direct VPC egress does not fit.
  - Add firewall rules that allow only Postgres (5432) and Redis (6379), and only from the Cloud Run subnet.
  - Allow SSH to the instance only through IAP. Add Cloud NAT for outbound traffic from the instance.
- **Storage.** A GCS bucket for media, with uniform bucket-level access. Give the Django service account access to this bucket only. Configure Django to use it through `django-storages`.
- **Secrets.** Store `DJANGO_SECRET_KEY`, `DATABASE_URL`, and `REDIS_URL` in Secret Manager. Pass them to the Cloud Run workloads as secret references.
- Add outputs for the Cloud Run URL, the registry path, and the media bucket name.
- Run `terraform fmt` and `terraform validate`. Do not run `terraform apply`.

### 13. Add Zed tasks

Add `.zed/tasks.json` so each local process starts from the Zed task picker. Make sure `.zed/` is not git-ignored, and commit the file.

- Give every task `"cwd": "$ZED_WORKTREE_ROOT"`, `"use_new_terminal": true`, `"reveal": "always"`, and `"hide": "never"`.
- Set `"allow_concurrent_runs": true` on the long-running tasks. Set it to false on the pytest task.
- Set `DJANGO_SETTINGS_MODULE` to `config.settings.local` and `DJANGO_READ_DOT_ENV_FILE` to `True` in `env` for every Django and Celery task.
- Add these tasks:
  - "Tailwind CSS Watch" runs `just tailwind-watch`.
  - "Django Server" runs `uv run python manage.py runserver`. Pick a port that is free on this machine and does not clash with another project in the portfolio. Do not leave it at 8000 if something already uses it.
  - "Celery Worker" runs `uv run celery -A config.celery_app worker --loglevel=info`.
  - "Celery Beat" runs `uv run celery -A config.celery_app beat --loglevel=info`.
  - "Run pytest" runs `uv run pytest --cov=<project_slug> --cov-report=html --cov-report=term`.
- If you add justfile recipes for the worker and beat, make the Zed tasks call those recipes instead.

### 14. Write AGENTS.md

Write an `AGENTS.md` in the new repo. It lists the stack, the architecture rules, the Basecoat component list, and the component toolbox above. It also lists these project rules:

- Never write migrations by hand. Generate them with `makemigrations`.
- Never use `# noqa`. Fix the cause of the lint error.
- Write no comments that narrate what the code does. Comment only non-obvious intent.
- Add no trailer lines to commit messages.
- Run `uv run pytest`, `uv run mypy <project_slug>`, and `pre-commit run --all-files` before every commit.
- Rebuild and commit `tailwind.css` after every template or CSS change.

### 15. Prove the skeleton works end to end

- Build one trivial slice: a home page made from Basecoat components. Use at least a button, a card, a dropdown menu, and a dialog that opens in an Unpoly layer. Compose them in one project cotton component. Add a Tailwind class. The theme toggle must work, and Basecoat must follow the dark theme.
- Add one test for the page.
- Add a trivial Celery task named `ping`. Add a test that runs it eagerly.
- Add a trivial websocket consumer on `ws/ping/` that replies `pong`. Add a test that connects with `channels.testing.WebsocketCommunicator`, sends a message, and checks the reply. Use the in-memory channel layer.
- Run `pytest`, `mypy`, and `pre-commit`. Report the exact results.
- Run the app and check the page in a browser. If you cannot run a browser, say which criteria you could not verify there.

### 16. Report

Report in plain language. Lead with the outcome. Then give:

- The repo path, the branch, the ticket URL, and the GitHub repo URL.
- What is verified, with the command and the result.
- What is not verified, and why. The first deploy is always on this list, because the operator runs it.
- The manual steps left for the operator:
  - Push `main` and the feature branch.
  - Create the Postgres database on the host or the database VM.
  - Start Redis locally.
  - Create the Terraform state bucket, then run `terraform apply`.

Remove the active-issue-skill marker.

Remind the operator that this is a KEPT skeleton and goes through the full SDLC: tests with > 80% coverage, Rex review, the security gate, and all merge gates. Build real features on top of the merged skeleton, one ticket at a time.

## Rules

1. **Ask when needed, never by reflex.** Do not re-ask what this skill decides. Ask one question at a time.
2. **Confirm outward-facing actions.** The GitHub repo, the project link, and the ticket each need a yes.
3. **KEPT, not throwaway.** Do not apply the `spike` label or any exemption label.
4. **Nothing pushes and nothing applies.** Do not run `git push` or `terraform apply`. The operator runs them.
5. **Use Basecoat first.** Never hand-roll a component that Basecoat ships.
6. **Do not install django-unicorn or tetra** in the skeleton.
7. **Branch name.** Always `feature/GH-<ticket>-walking-skeleton`.
8. **Report what is not verified.** Do not describe an unrun check as passed.

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
