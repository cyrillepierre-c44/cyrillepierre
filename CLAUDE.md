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

**Deployment**: Heroku. Deploy with `git push heroku master`. App Heroku : `cyrillepierre`. Site en production : **cyrillepierre.com** (pas cyrillepierre.fr).

**CSS**: sassc-rails pipeline — stylesheets live in `app/assets/stylesheets/`. Bootstrap variables/overrides go before `@import "bootstrap"`.

**Linting**: rubocop-rails-omakase style. Max line length 120. `bin/rubocop` is the wrapper. Rubocop excludes `bin/`, `db/`, `config/`, `test/`.

**Security CI steps**: brakeman (static analysis) and bundler-audit (gem CVEs) run as part of `bin/ci`.

## Page CV (`app/views/pages/cv.html.erb`)

Page standalone — elle n'utilise **pas** le layout Rails (`layout false` dans le controller). Tout le CSS et le JS sont inline dans le fichier.

Fonctionnalités :
- **Mode papier** : toggle via classe `paper-mode` sur `<body>`. Bouton affiche "🖨 Version papier" / "🎨 Version couleur" (texte doré en mode actif).
- **URL param `?mode=papier`** : active automatiquement le mode papier au chargement (lu par un IIFE au bas de la page).
- **Bouton Partager** : utilise `navigator.share` (Web Share API, natif mobile) avec fallback `navigator.clipboard` (copie du lien, feedback "✓ Lien copié !" 2 s). L'URL partagée inclut `?mode=papier` si le mode est actif.
- **Impression** : `@media print` force les dimensions A4 exactes (794×1123 px). Le bouton "⎙ Imprimer" appelle `window.print()`.
- **Scaling mobile** : JS transform `scale()` sur `.page` pour les viewports < 830 px. Annulé avant impression (`beforeprint`) et restauré après (`afterprint`).
- **Couleurs** : fond sombre `#1a2332`, accent doré `#c9a961`. Les boutons de la barre utilisent ces deux couleurs.
