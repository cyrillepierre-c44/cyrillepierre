# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Stack

Rails 8.1 / PostgreSQL / Puma. Generated from the [Le Wagon rails-templates](https://github.com/lewagon/rails-templates).

Frontend: Bootstrap 5.3, importmap (no Node/webpack — JS is loaded via `config/importmap.rb`), Stimulus, Turbo, Font Awesome 6, simple_form.

## Commands

```bash
bin/setup              # install gems, create & migrate DB
rails s                # start server (or bin/dev for Procfile)
rails c                # console
rails db:migrate
rails test             # full test suite
rails test test/models/foo_test.rb  # single test file
bin/rubocop            # lint
bin/ci                 # full CI: setup → rubocop → brakeman → bundler-audit → importmap audit → tests → seed test
```

## Architecture notes

**JavaScript**: importmap-only — add packages with `bin/importmap pin <package>`, not npm. Stimulus controllers live in `app/javascript/controllers/`; `index.js` auto-registers them. Bootstrap and Popper are imported in `application.js`.

**Background/cache/cable**: production uses four separate PostgreSQL databases (primary, cache, queue, cable) via solid_cache, solid_queue, solid_cable. In development/test a single DB is used.

**Deployment**: Kamal (`config/deploy.yml`, `.kamal/secrets`). Deploy with `kamal deploy`.

**CSS**: sassc-rails pipeline — stylesheets live in `app/assets/stylesheets/`. Bootstrap variables/overrides go before `@import "bootstrap"`.

**Linting**: rubocop-rails-omakase style. Max line length 120. `bin/rubocop` is the wrapper. Rubocop excludes `bin/`, `db/`, `config/`, `test/`.

**Security CI steps**: brakeman (static analysis) and bundler-audit (gem CVEs) run as part of `bin/ci`.
