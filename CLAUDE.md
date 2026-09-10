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

**Deployment**: Heroku. Deploy with `git push heroku master`. App Heroku : `cyrillepierre`. Site en production : **cyrillepierre.com** (pas cyrillepierre.fr). Les migrations tournent via la `release` phase du `Procfile`. `config.force_ssl` est actif ; **`assume_ssl` doit rester désactivé** sur Heroku (le routeur envoie déjà `X-Forwarded-Proto` ; l'activer empêche la redirection HTTP→HTTPS de se déclencher).

**DNS / domaine nu** : depuis le 09/08/2026, les DNS sont **délégués à Cloudflare** (plan Free, NS `imani`/`lee.ns.cloudflare.com`, runbook suivi : `docs/runbook-dns-cloudflare.md`). L'apex `https://cyrillepierre.com` est proxifié par Cloudflare (SSL Full strict + Always Use HTTPS) et répond en 301 vers `www`, servi en direct par Heroku (`www` en DNS only). Les MX de transfert d'emails Namecheap (eforward) sont recréés à l'identique dans la zone Cloudflare. Étapes J+2 restantes au 09/08 : DNSSEC (côté Cloudflare + DS chez Namecheap), CAA, DMARC.

**CSS**: sassc-rails pipeline — stylesheets live in `app/assets/stylesheets/`. Bootstrap variables/overrides go before `@import "bootstrap"`.

**Linting**: `.rubocop.yml` est autonome (il n'hérite **pas** de `rubocop-rails-omakase`, malgré la présence du gem) — d'où une configuration à la main avec beaucoup de cops désactivés. Max line length 120. `bin/rubocop` is the wrapper. Exclusions : `bin/`, `db/`, `config/`, `test/`, **`vendor/`** (indispensable : en CI les gems sont vendorées, et redéfinir `AllCops.Exclude` écrase la liste par défaut de RuboCop, qui linterait alors tout Rails). Les cops `Metrics/*` sont désactivés : les méthodes les plus longues construisent des prompts LLM en heredocs de ~100 lignes.

**Security CI steps** : `.github/workflows/ci.yml` rejoue sur chaque push et PR les étapes de `config/ci.rb` (RuboCop, Brakeman, bundler-audit, audit importmap, tests, seeds). Reproduire les échecs en local avec `CI=1 bin/rails test` (eager loading).

⚠️ **Piège Brakeman** : le binstub `bin/brakeman` généré par Rails ajoute `--ensure-latest`, qui fait sortir Brakeman en **code 5 dès qu'une version plus récente du gem est publiée**, sans aucun avertissement de sécurité. La CI utilise donc `bundle exec brakeman` — sinon elle passe au rouge un matin sans qu'une ligne de code ait bougé.

**Rate limiting** : `rack-attack` (`config/initializers/rack_attack.rb`) protège les endpoints `/contact/chat`, `/contact/summarize`, `/contact/infer_company`, qui déclenchent chacun un appel Mammouth **payant** — c'est un garde-fou de facturation autant que de sécurité. En production le compteur s'appuie sur `Rails.cache` (solid_cache, qui gère bien `increment`).

**Monitoring** : Sentry (`config/initializers/sentry.rb`) ne s'initialise **que** si `SENTRY_DSN` est présente — rien ne part depuis le développement, les tests ou la CI. `send_default_pii = false` (RGPD). Point de santé : `/up`.

**Content Security Policy** (`config/initializers/content_security_policy.rb`) : active, avec les seules origines réellement chargées (fonts.googleapis.com / fonts.gstatic.com pour les polices, esm.sh pour le paquet `marked` de l'importmap, res.cloudinary.com pour Active Storage).

⚠️ **Ne PAS revenir au nonce `request.session.id`** (la suggestion du template Rails) : aucune page publique n'écrit en session, donc `session.id` y vaut `nil`, le nonce sort **vide** (`'nonce-'`), et un nonce vide bloque toute balise inline — dont `<script type="importmap">`, ce qui tue Turbo, Stimulus et Bootstrap sur tout le site. Le nonce est donc aléatoire par réponse. Conséquence assumée : l'ETag change à chaque réponse, le cache conditionnel du HTML ne joue plus (coût faible, `must-revalidate` imposait déjà l'aller-retour). `test/controllers/security_headers_test.rb` verrouille tout ça, notamment le fait que la balise importmap porte bien le nonce.

La CSP est **levée sur la seule page `/cv`** (`content_security_policy false, only: :cv` dans `PagesController`) : page autonome dont le CSS/JS est inline avec des gestionnaires `onclick`, qu'un nonce ne peut pas couvrir, et qui n'affiche aucune donnée saisie par un visiteur.

**Couverture de tests** : SimpleCov écrit `coverage/index.html` à chaque `bin/rails test`. Environ **99 %** des lignes aujourd'hui (objectif 80 % atteint en août 2026 : WebMock coupe tout appel réseau réel — Mammouth, LinkedIn, Cloudinary — et `Rack::Attack` est désactivé dans la suite sauf pour `test/integration/rate_limiting_test.rb` qui le réactive avec un compteur mémoire dédié). Le merge des workers parallèles est câblé dans `test_helper.rb` (`parallelize_setup`/`parallelize_teardown`), sans quoi seule la couverture du dernier worker serait rapportée.

**Auth & authorization**: Devise (`User` model, registrations disabled — comptes créés via `rails c`/seeds) + Pundit (`ApplicationPolicy`, `GenerationPolicy`). `User` a un `role` enum (`editor`/`admin`). `ApplicationController` inclut `Pundit::Authorization` et rescue `Pundit::NotAuthorizedError` en redirigeant avec une alerte. Un `after_action :verify_pundit_authorization` global garantit qu'aucune action du Studio ne passe sans contrôle : callback unique qui dispatche sur `action_name` (`verify_policy_scoped` pour `index`, `verify_authorized` sinon), **sans `only:`/`except:`** — la variante `except: :index` casse dès qu'un controller n'a pas d'action `index`, `raise_on_missing_callback_actions` étant actif en test. `skip_pundit?` limite la vérification aux controllers sous `studio/` (les pages publiques et Devise n'ont rien à autoriser).

**Stockage (Active Storage)** : service `:cloudinary` en production (`config/environments/production.rb`) — le disque Heroku est éphémère, `:local` perdait les fichiers à chaque redéploiement/restart. Le gem officiel `cloudinary` fournit `ActiveStorage::Service::CloudinaryService` et lit `CLOUDINARY_URL` automatiquement (rien à dupliquer dans `config/storage.yml`, juste `service: Cloudinary`). En développement, `:cloudinary` si `CLOUDINARY_URL` est présente dans `.env`, sinon fallback `:local` ; `test` reste toujours sur `:local`/`Disk` (pas de dépendance réseau dans la suite).

**Mailer** : `config.action_mailer.default_url_options` doit utiliser `cyrillepierre.com` (pas `.fr`) en production — erreur déjà corrigée une fois, à ne pas réintroduire.

**Chiffrement (Active Record Encryption)** : utilisé pour `User#linkedin_access_token`. Clés via ENV (`AR_ENCRYPTION_PRIMARY_KEY`/`AR_ENCRYPTION_DETERMINISTIC_KEY`/`AR_ENCRYPTION_KEY_DERIVATION_SALT`, générées une fois via `bin/rails db:encryption:init`), branchées dans `config/application.rb` — pas de `credentials.yml.enc`, comme tous les autres secrets de cette app.

## Studio (`/studio`, `app/controllers/studio/`, `app/models/generation.rb`)

Outil de génération de contenu par IA, réservé aux utilisateurs Devise authentifiés. Modèle `Generation` (`belongs_to :user`, `has_one_attached :source_file`, `has_one_attached :visual`).

**Types de contenu** (`Generation::KIND`, enum `kind`) : `linkedin_post`, `cover_letter`, `commercial_proposal`, `site_actu`. Les deux derniers types "structurés" (lettre, proposition) utilisent un format de sortie en 4 sections marquées (`SECTION_MARKERS` : version finale / à personnaliser / à vérifier / version courte), parsées par `Generation#sections`.

**Sources optionnelles** (texte collé, fichier `.txt`/`.md`/`.pdf` 10 Mo max via `FileTextExtractor`, ou URL via `UrlScraper`) — toutes facultatives : si aucune n'est fournie, l'IA génère un contenu générique à partir du profil de Cyrille (CV complet via `CvText`, qui rend `pages/cv` et en extrait le texte brut, + catalogue de réalisations `RealisationCatalog::ITEMS`, ~26 réalisations taggées, certaines avec un `semantic_scope` précisant pour quels sujets les utiliser/ne pas utiliser).

**Génération** : `ContentGenerator` (service) construit le prompt système (règles d'écriture anti-IA-générique + prompt spécifique au `kind`) et appelle le LLM via `RubyLLM`. Provider unique : **Mammouth.ai** (clé `MAMMOUTH_API_KEY`, endpoint OpenAI-compatible `https://api.mammouth.ai/v1`) — l'ancien provider GitHub Models (gratuit, `GITHUB_KEY`) a expiré et a été retiré en août 2026 (choix de modèle, relecture, chatbot contact : tout passe par Mammouth désormais). Modèles au choix par génération (`Generation::LLM_MODELS`) : Gemini 3.5 Flash (défaut, `Generation::DEFAULT_LLM_MODEL`), Claude Sonnet 4.6/Opus 4.8, Mistral Large 3, GPT-5.4. La relecture orthographique finale tourne toujours sur Gemini 3.5 Flash (`ContentGenerator::PROOFREADING_MODEL`, rapide/peu cher) quel que soit le modèle choisi pour le brouillon. Le chatbot du formulaire de contact (`ContactsController#call_llm`, appel HTTP direct hors RubyLLM) utilise aussi Mammouth avec Gemini 3.5 Flash.

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

## Pages légales (`/mentions-legales`, `/politique-de-confidentialite`)

Deux pages publiques statiques (`PagesController#legal` / `#privacy`), liées depuis le pied de
page et depuis la mention RGPD du formulaire de contact. Ajoutées quand le site s'est mis à
**conserver** des prospects (voir ci-dessous) : informer devient obligatoire à partir de là.

⚠️ **Valeurs à renseigner avant mise en ligne** : adresse professionnelle, téléphone, statut
juridique et SIRET, TVA. Elles apparaissent dans la page entourées de `.legal-todo` (encadré
orange pointillé, volontairement voyant) et un test — `pages_controller_test.rb` — vérifie leur
présence. Une fois complétées, supprimer ce test.

La politique de confidentialité annonce une conservation de **trois ans après le dernier
contact**, appliquée par `ProspectPurgeJob` (planifié dans `config/recurring.yml`, production
uniquement, tous les jours à 4h). Le seuil vit dans `Prospect::RETENTION` : le changer sans
corriger la page rendrait celle-ci fausse, et inversement. `test/jobs/recurring_schedule_test.rb`
vérifie que le YAML pointe toujours vers une classe existante — le job n'est appelé de nulle
part ailleurs, un renommage le désactiverait en silence. Solid Queue tourne dans Puma via
`SOLID_QUEUE_IN_PUMA` : sans cette variable sur Heroku, aucune tâche récurrente ne s'exécute.
Et elle avertit
que le contenu du chat part chez un prestataire LLM : à mettre à jour si le provider change
(aujourd'hui Mammouth.ai), au même titre que la liste des sous-traitants (Heroku, Cloudflare,
Cloudinary, Sentry, Gmail).

## Pipeline commercial (`/studio/prospects`, `app/models/prospect.rb`)

Colonne vertébrale du suivi commercial. Avant, l'assistant du formulaire de contact collectait
défi, secteur, effectif et résumé, puis tout partait dans un mail et n'existait plus nulle part :
aucun pipeline, aucune relance, aucun historique. `Prospect` persiste cette qualification.

- **Alimentation automatique** : `ContactsController#create` appelle `Prospect.record_contact_request`
  après l'envoi des mails. L'écriture est **rescue** volontairement : la demande du visiteur est déjà
  partie par mail, un échec d'écriture ne doit jamais lui afficher une erreur ni lui faire tout ressaisir.
  L'historique du chat (JSON) est converti en transcription lisible (`contact_history_text`).
- **Saisie manuelle** : pour les contacts du réseau (LinkedIn, Soce, Le Wagon, 60 000 rebonds),
  d'où l'enum `source`.
- **`user` est optionnel** : les demandes venues du site n'ont pas d'utilisateur connecté au moment
  de leur création. `ProspectPolicy::Scope` les réserve donc aux admins ; un éditeur ne voit que ses
  propres saisies. `has_many :prospects, dependent: :nullify` sur `User` — une piste commerciale
  survit à la suppression d'un compte, contrairement aux générations.
- **Pipeline** : `status` (nouveau → à contacter → en discussion → proposition → gagné/perdu/veille),
  `next_action` + `next_action_on`. L'index remonte en tête les relances dues (`ouverts.en_retard`),
  c'est la première chose à voir le matin.
- **Pont vers le Studio** : `Prospect#brief_for_proposal` assemble le besoin déjà qualifié, et le
  bouton « Rédiger une proposition » ouvre `new_studio_generation_path` avec `kind`, `title` et
  `input_text` pré-remplis — d'où les paramètres acceptés par `Studio::GenerationsController#new`.
- **RGPD** : la mention du formulaire de contact précise désormais la conservation des données le
  temps du suivi. Des mentions légales et une politique de confidentialité restent à ajouter.

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
