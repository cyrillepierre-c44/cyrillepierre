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

**Stockage (Active Storage)** : service `:cloudinary` en production (`config/environments/production.rb`) — le disque Heroku est éphémère, `:local` perdait les fichiers à chaque redéploiement/restart. Le gem officiel `cloudinary` fournit `ActiveStorage::Service::CloudinaryService` et lit `CLOUDINARY_URL` automatiquement (rien à dupliquer dans `config/storage.yml`, juste `service: Cloudinary`). En développement, `:cloudinary` si `CLOUDINARY_URL` est présente dans `.env`, sinon fallback `:local` ; `test` reste toujours sur `:local`/`Disk` (pas de dépendance réseau dans la suite).

**Mailer** : `config.action_mailer.default_url_options` doit utiliser `cyrillepierre.com` (pas `.fr`) en production — erreur déjà corrigée une fois, à ne pas réintroduire.

**Chiffrement (Active Record Encryption)** : utilisé pour `User#linkedin_access_token`. Clés via ENV (`AR_ENCRYPTION_PRIMARY_KEY`/`AR_ENCRYPTION_DETERMINISTIC_KEY`/`AR_ENCRYPTION_KEY_DERIVATION_SALT`, générées une fois via `bin/rails db:encryption:init`), branchées dans `config/application.rb` — pas de `credentials.yml.enc`, comme tous les autres secrets de cette app.

## Studio (`/studio`, `app/controllers/studio/`, `app/models/generation.rb`)

Outil de génération de contenu par IA, réservé aux utilisateurs Devise authentifiés. Modèle `Generation` (`belongs_to :user`, `has_one_attached :source_file`, `has_one_attached :visual`).

**Types de contenu** (`Generation::KIND`, enum `kind`) : `linkedin_post`, `cover_letter`, `commercial_proposal`, `site_actu`. Les deux derniers types "structurés" (lettre, proposition) utilisent un format de sortie en 4 sections marquées (`SECTION_MARKERS` : version finale / à personnaliser / à vérifier / version courte), parsées par `Generation#sections`.

**Sources optionnelles** (texte collé, fichier `.txt`/`.md`/`.pdf` 10 Mo max via `FileTextExtractor`, ou URL via `UrlScraper`) — toutes facultatives : si aucune n'est fournie, l'IA génère un contenu générique à partir du profil de Cyrille (CV complet via `CvText`, qui rend `pages/cv` et en extrait le texte brut, + catalogue de réalisations `RealisationCatalog::ITEMS`, ~26 réalisations taggées, certaines avec un `semantic_scope` précisant pour quels sujets les utiliser/ne pas utiliser).

**Génération** : `ContentGenerator` (service) construit le prompt système (règles d'écriture anti-IA-générique + prompt spécifique au `kind`) et appelle le LLM via `RubyLLM`. Deux providers au choix par génération (`Generation::LLM_MODELS`) : le LLM par défaut de l'app (GitHub Models — seulement 4 modèles chat disponibles : GPT-4o, GPT-4o mini, Llama 3.1 405B/8B) ou Mammouth.ai (clé `MAMMOUTH_API_KEY`, endpoint OpenAI-compatible, catalogue bien plus large : Claude Sonnet 4.6/Opus 4.8, Mistral Large 3, GPT-5.4, Gemini 3.5 Flash...). La relecture orthographique finale tourne toujours sur GitHub Models (gratuit) quel que soit le modèle choisi pour le brouillon.

**Réalisation verrouillée pour les posts sans source** : `Generation#assign_auto_realisation` (callback `before_save`, uniquement si `linkedin_post?` et aucune source) fixe `realisation_id` par rotation via `RealisationCatalog.pick_unused` (exclut les réalisations utilisées dans les 10 derniers posts de l'utilisateur). But : éviter que le LLM invente un sujet puis cherche après-coup une réalisation qui colle à peu près — la réalisation est choisie *avant* génération et son `semantic_scope` devient le cadre obligatoire du prompt (`ContentGenerator#locked_realisation_block`). Un sélecteur dans le formulaire (`_form.html.erb`, visible seulement pour `linkedin_post`) permet d'imposer une réalisation précise à la place de la rotation auto. Dès qu'une source/brief est fournie, ce verrouillage ne s'applique pas : le LLM garde le catalogue complet et choisit librement.

**Anonymisation des entreprises** : pour `linkedin_post` et `site_actu` (contenus publics), `ContentGenerator::ANONYMIZE_COMPANIES_RULE` interdit de citer le nom réel d'une entreprise/marque, et `anonymized_realisations_str`/`locked_realisation_block` décrivent les réalisations par secteur/taille (`scale`, `type_orga`) plutôt que par `context` (qui contient le nom). `cover_letter` et `commercial_proposal` gardent les vrais noms (CV et références clients = attendu et utile pour ces usages privés).

**Posts LinkedIn** :
- champ `orientation` (enum : `consultant`, `transition_management`, `cdi_search`) change le ton et l'appel à l'action.
- le prompt inclut les 5 derniers posts publiés/générés pour éviter de réutiliser la même réalisation ou accroche.
- canevas imposé (Hook / Contexte / Résultat / Ouverture), gras limité à 2 passages courts (jamais une phrase entière) et 3 à 5 emojis ciblés — règles renforcées plusieurs fois car les LLM respectent mal les contraintes de comptage strict, contrairement aux contraintes de présence/interdiction (anonymisation, structure) qui sont bien suivies.
- `LinkedinTextFormatter` (`app/services/linkedin_text_formatter.rb`) convertit le `**gras** markdown` en vrais caractères Unicode gras à l'affichage/copie (LinkedIn ne rend pas le markdown) — gère aussi les lettres accentuées (décomposition NFD, base + accent). Les symboles type `%` n'ont pas d'équivalent gras en Unicode : limite inhérente, pas un bug.
- **Visuel généré par IA** : `VisualGenerator` (`app/services/visual_generator.rb`) appelle Mammouth pour produire une illustration (palette bleu marine/doré, jauge ou graphique rouge→vert comme métaphore de mesure, personnages en pictogrammes sans visage — "no human faces" seul ne suffit pas, les modèles dessinent quand même des profils, il faut expliciter "no eyes/nose/mouth"). Modèle choisi par génération (`Generation::IMAGE_MODELS` : `gemini-2.5-flash-image` par défaut, ou `gemini-3.1-flash-image-preview`) — `gpt-5.4-image-2` testé et écarté (timeout Cloudflare systématique sur Mammouth). Le prompt **adapte la scène au sujet réel** du post (production/usine si ça parle de machines, planning/calendrier si RH ou horaires, organigramme si management — jamais d'usine par défaut sous prétexte que c'est un post industriel). Quand une réalisation est verrouillée (voir ci-dessus), le prompt ajoute son texte complet et son `visual_hint` (description de l'illustration SVG existante pour cette réalisation sur `/realisations`, voir plus bas) pour que le visuel s'inspire du design du site ; sans réalisation verrouillée (l'IA a choisi librement le thème), aucune contrainte de design supplémentaire — liberté totale. Limite connue : malgré la consigne "no text", ces modèles ajoutent parfois du texte parasite/illisible dans l'image — pas de solution fiable trouvée, à régénérer si besoin. Bouton "Générer/Régénérer le visuel" sur la page de détail, ou case "Générer aussi un visuel" sur le formulaire de création (texte puis image dans la même requête ; la barre de progression switch de texte après un délai fixe côté JS, faute de suivi temps réel — requête synchrone, pas de polling).
- **Édition manuelle** : titre (clic sur le `<h1>`) et texte généré (`output`) sont éditables en ligne sur la page de détail. Un seul `data-controller="studio-output-edit"` couvre toute la `.studio-card` (toolbar + contenu) — nécessaire pour que le bouton "Modifier le texte" dans la toolbar (desktop, entre Régénérer et Supprimer) et sa variante sous le texte (mobile, `.studio-edit-toolbar-btn`/`.studio-edit-mobile-btn` en CSS) partagent les mêmes targets `display`/`form`. PATCH sur l'action `update` existante.

**Catalogue de réalisations — `visual_hint`** : chaque entrée de `RealisationCatalog::ITEMS` a un champ `visual_hint` (texte court décrivant la composition de l'illustration SVG faite à la main pour cette réalisation sur `/realisations` — ex. boîtes qui fusionnent, jauge, frise chronologique). **Règle à respecter** : toute nouvelle réalisation ajoutée au catalogue doit avoir à la fois une nouvelle illustration SVG sur `/realisations` et son `visual_hint` correspondant — jamais l'un sans l'autre (sinon `VisualGenerator` se rabat silencieusement sur les faits bruts, sans inspiration de design).

**Publication** : seul `site_actu` est publiable (`publishable?`) — actions `publish`/`unpublish` passent `status` à `published`/`generated` et fixent `published_at`. Les actus publiées s'affichent sur `/actus` (`ActusController`).

**Fuseau horaire** : Paris (cf. commit "fuseau horaire Paris" du 18/06).

## Publication directe sur LinkedIn (`LinkedinAuthController`, `LinkedinPublisher`)

OAuth2 (`LinkedinAuthController#connect`/`callback`/`disconnect`, hors namespace `studio`) : redirige vers LinkedIn, vérifie le `state` (anti-CSRF) au retour, échange le `code` puis appelle `/v2/userinfo` pour récupérer l'identité du membre. Stocke `linkedin_access_token` (chiffré), `linkedin_token_expires_at` (~60 jours, pas de refresh token simple pour ce niveau d'accès → reconnexion périodique), `linkedin_member_urn` sur `User`.

**Piège redirect_uri** : le site redirige le domaine nu vers `www.cyrillepierre.com` — l'URL de callback générée par Rails (`linkedin_auth_callback_url`) suit donc le host réellement utilisé. Il faut enregistrer **les deux** variantes (`https://cyrillepierre.com/...` et `https://www.cyrillepierre.com/...`) dans "Authorized redirect URLs" de l'app LinkedIn, sinon erreur "redirect_uri does not match".

`LinkedinPublisher` (`app/services/linkedin_publisher.rb`) publie le texte (`LinkedinTextFormatter.call`, donc avec le gras Unicode comme dans l'aperçu) et le visuel attaché s'il y en a un, via `/rest/posts` + `/rest/images`. Points à surveiller :
- `LINKEDIN_VERSION` (header `LinkedIn-Version`, format YYYYMM) se périme après ~12 mois → erreur 426 "version not active". À rafraîchir au moins une fois par an.
- L'upload d'image (`PUT` vers l'`uploadUrl` retournée par `initializeUpload`) **exige** l'en-tête `Content-Type: application/octet-stream`, sinon 400 silencieux côté LinkedIn — la réponse du `PUT` doit être vérifiée explicitement (bug déjà rencontré : post créé en référençant une image jamais réellement envoyée, LinkedIn retire alors le post après coup).
- L'image uploadée est traitée de façon asynchrone (PROCESSING → AVAILABLE) — `wait_for_image_ready` poll brièvement `/rest/images/{id}`, avec repli sur une attente fixe si l'endpoint n'est pas accessible avec nos scopes (`w_member_social`/`openid`/`profile` ne donnent pas accès en lecture aux posts/images, juste en création).
- L'URN du post créé (header `x-restli-id` de la réponse) est stocké dans `linkedin_post_urn` → `Generation#linkedin_post_url` construit le permalien public (`https://www.linkedin.com/feed/update/{urn}/`), affiché comme lien "voir le post" après publication. Sans ça, aucun moyen de vérifier après coup qu'un post a bien été créé (pas de droit de lecture via l'API).

## Page CV (`app/views/pages/cv.html.erb`)

Page standalone — elle n'utilise **pas** le layout Rails (`layout false` dans le controller). Tout le CSS et le JS sont inline dans le fichier.

Fonctionnalités :
- **Mode papier** : toggle via classe `paper-mode` sur `<body>`. Bouton affiche "🖨 Version papier" / "🎨 Version couleur" (texte doré en mode actif). Le libellé s'adapte à la langue courante (`updatePaperBtn()`).
- **Bascule FR/EN** : `<select id="langSelect">` (même style `.print-quality` que le sélecteur de qualité) appelle `applyLang(lang)` — met à jour via `innerHTML` tous les éléments identifiés par `id` (`cv-exp-1-title`, `cv-comp-3-desc`, etc.) à partir de l'objet `TRANSLATIONS` (défini dans le second bloc `<script>`). Chaque élément traduisible porte un `id` préfixé `cv-`. Le `<html lang>` est aussi mis à jour.
- **URL params** : `?mode=papier` active le mode papier, `?lang=en` active l'anglais — les deux sont lus dans `DOMContentLoaded` (second bloc script). `shareCV` inclut les deux params si actifs.
- **Bouton Partager** : utilise `navigator.share` (Web Share API, natif mobile) avec fallback `navigator.clipboard`. Feedback "✓ Lien copié !" / "✓ Link copied!" selon la langue. L'URL partagée inclut `?mode=papier` et/ou `?lang=en` si actifs.
- **Impression** : `@media print` force les dimensions A4 exactes (794×1123 px). Le bouton "⎙ Imprimer" appelle `window.print()`. Un sélecteur "Qualité d'impression" (Standard/Compacte) permute la photo entre `/images/cyrille.jpg` et `/images/cyrille-print-compact.jpg` juste avant l'impression (`beforeprint`/`afterprint`) pour garder le PDF généré sous 2 Mo.
- **Scaling mobile** : JS transform `scale()` sur `.page` pour les viewports < 830 px. Annulé avant impression (`beforeprint`) et restauré après (`afterprint`).
- **Couleurs** : fond sombre `#1a2332`, accent doré `#c9a961`. Les boutons de la barre utilisent ces deux couleurs.

## UI

**`<select>` sombres** : `.cf-input option` (`app/assets/stylesheets/pages/_contact.scss`) force un fond sombre opaque sur les `<option>` : le champ `<select>` a un fond quasi-transparent qui passe bien à l'écran, mais certains navigateurs rendent le menu déroulant natif avec un fond clair par défaut tout en gardant notre texte clair hérité — illisible sans ce correctif.

**Flash messages** : `data-controller="flash"` (`app/javascript/controllers/flash_controller.js`) sur `.alert-flash-notice`/`.alert-flash-alert` (`app/views/layouts/application.html.erb`) — disparition automatique après 4s (`durationValue`), avant ça le message restait affiché jusqu'à la prochaine navigation.

**Studio mobile** (`app/assets/stylesheets/pages/_studio.scss`, breakpoint `680px`) : boutons/formulaires en pleine largeur et empilés en colonne sous 680px (`.studio-actions`, `.studio-list-item`, `.studio-regenerate-form`...) — les badges et boutons ont des tailles très différentes par nature (pastille vs bouton plein), les mélanger dans une même ligne sur petit écran donnait un rendu incohérent.

**Bouton Copier** : icône seule (`fa-regular fa-copy`, classe `.studio-icon-btn`) superposée en haut à droite de la zone de texte concernée (`.studio-icon-btn--overlay`, le conteneur passe en `position: relative` via `.studio-output-box` ou `.studio-linkedin-preview`) plutôt qu'un bouton texte séparé en dessous — variante `--light` pour la carte blanche de l'aperçu LinkedIn. `studio_clipboard_controller.js` utilise `innerHTML` (pas `textContent`) pour le feedback "✓ copié", sinon l'icône `<i>` est détruite au moment de la restauration.
