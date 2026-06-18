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

**Auth & authorization**: Devise (`User` model, registrations disabled — comptes créés via `rails c`/seeds) + Pundit (`ApplicationPolicy`, `GenerationPolicy`). `User` a un `role` enum (`editor`/`admin`). `ApplicationController` inclut `Pundit::Authorization` et rescue `Pundit::NotAuthorizedError` en redirigeant avec une alerte.

## Studio (`/studio`, `app/controllers/studio/`, `app/models/generation.rb`)

Outil de génération de contenu par IA, réservé aux utilisateurs Devise authentifiés. Modèle `Generation` (`belongs_to :user`, `has_one_attached :source_file`).

**Types de contenu** (`Generation::KIND`, enum `kind`) : `linkedin_post`, `cover_letter`, `commercial_proposal`, `site_actu`. Les deux derniers types "structurés" (lettre, proposition) utilisent un format de sortie en 4 sections marquées (`SECTION_MARKERS` : version finale / à personnaliser / à vérifier / version courte), parsées par `Generation#sections`.

**Sources optionnelles** (texte collé, fichier `.txt`/`.md`/`.pdf` 10 Mo max via `FileTextExtractor`, ou URL via `UrlScraper`) — toutes facultatives : si aucune n'est fournie, l'IA génère un contenu générique à partir du profil de Cyrille (CV complet via `CvText`, qui rend `pages/cv` et en extrait le texte brut, + catalogue de réalisations `RealisationCatalog::ITEMS`, ~26 réalisations taggées).

**Génération** : `ContentGenerator` (service) construit le prompt système (règles d'écriture anti-IA-générique + prompt spécifique au `kind`) et appelle le LLM via `RubyLLM`. Deux providers au choix par génération (`Generation::LLM_MODELS`) : le LLM par défaut de l'app (GitHub Models) ou Mammouth.ai (clé `MAMMOUTH_API_KEY`, endpoint OpenAI-compatible). La relecture orthographique finale tourne toujours sur GitHub Models (gratuit) quel que soit le modèle choisi pour le brouillon.

**Posts LinkedIn** : champ `orientation` (enum : `consultant`, `transition_management`, `cdi_search`) change le ton et l'appel à l'action. Le prompt inclut les 5 derniers posts publiés/générés pour éviter de réutiliser la même réalisation ou accroche.

**Publication** : seul `site_actu` est publiable (`publishable?`) — actions `publish`/`unpublish` passent `status` à `published`/`generated` et fixent `published_at`. Les actus publiées s'affichent sur `/actus` (`ActusController`).

**Fuseau horaire** : Paris (cf. commit "fuseau horaire Paris" du 18/06).

## Page CV (`app/views/pages/cv.html.erb`)

Page standalone — elle n'utilise **pas** le layout Rails (`layout false` dans le controller). Tout le CSS et le JS sont inline dans le fichier.

Fonctionnalités :
- **Mode papier** : toggle via classe `paper-mode` sur `<body>`. Bouton affiche "🖨 Version papier" / "🎨 Version couleur" (texte doré en mode actif).
- **URL param `?mode=papier`** : active automatiquement le mode papier au chargement (lu par un IIFE au bas de la page).
- **Bouton Partager** : utilise `navigator.share` (Web Share API, natif mobile) avec fallback `navigator.clipboard` (copie du lien, feedback "✓ Lien copié !" 2 s). L'URL partagée inclut `?mode=papier` si le mode est actif.
- **Impression** : `@media print` force les dimensions A4 exactes (794×1123 px). Le bouton "⎙ Imprimer" appelle `window.print()`.
- **Scaling mobile** : JS transform `scale()` sur `.page` pour les viewports < 830 px. Annulé avant impression (`beforeprint`) et restauré après (`afterprint`).
- **Couleurs** : fond sombre `#1a2332`, accent doré `#c9a961`. Les boutons de la barre utilisent ces deux couleurs.
