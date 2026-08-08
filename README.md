# cyrillepierre.com

Site professionnel de Cyrille PIERRE — consultant indépendant et manager de transition
(excellence opérationnelle, transformation, tech/IA).

En production : **https://www.cyrillepierre.com**

Le site comporte trois parties :

- les **pages publiques** (profil, expertises, réalisations, actualités) ;
- une page **CV** autonome (`/cv`), imprimable en A4, bilingue FR/EN, avec un mode papier ;
- le **Studio** (`/studio`), un outil privé de génération de contenu par IA (posts LinkedIn,
  lettres de motivation, propositions commerciales, actualités du site), avec publication
  directe sur LinkedIn.

## Stack

Rails 8.1 · PostgreSQL · Puma · Bootstrap 5.3 · Hotwire (Turbo + Stimulus) · importmap
(pas de Node ni de bundler JS) · Devise + Pundit · Active Storage sur Cloudinary ·
RubyLLM vers Mammouth.ai.

## Démarrage

```bash
bin/setup               # installe les gems, crée et migre la base, démarre le serveur
cp .env.example .env    # puis remplir les variables (voir ci-dessous)
```

Ensuite, au quotidien :

```bash
bin/dev                 # serveur de développement
bin/rails console
bin/rails test          # suite complète
bin/rails test test/models/generation_test.rb   # un seul fichier
bin/rubocop             # lint
bin/ci                  # tout l'enchaînement de la CI en local
```

Les emails de développement sont consultables sur `/letter_opener`.

## Variables d'environnement

Toutes les valeurs sensibles passent par l'environnement : ce projet n'utilise pas
`credentials.yml.enc`. `.env.example` liste chaque variable avec son rôle ; `.env` n'est
jamais committé. En production, elles sont posées sur Heroku (`heroku config:set`).

L'essentiel :

| Variable | Rôle |
|---|---|
| `MAMMOUTH_API_KEY` | Fournisseur LLM unique (Studio + chatbot de contact) |
| `CLOUDINARY_URL` | Stockage Active Storage — obligatoire en production |
| `AR_ENCRYPTION_*` | Chiffrement du token LinkedIn (`bin/rails db:encryption:init`) |
| `LINKEDIN_CLIENT_*` | OAuth2 pour la publication LinkedIn |
| `GMAIL_USERNAME` / `GMAIL_PASSWORD` | SMTP du formulaire de contact (mot de passe d'application) |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | Compte administrateur initial, créé par `db/seeds.rb` |
| `SENTRY_DSN` | Remontée d'erreurs — laisser vide en développement |

Les inscriptions Devise sont désactivées : le premier compte se crée par les seeds, les
suivants en console.

## Tests et qualité

```bash
bin/rails test          # 71 tests
CI=1 bin/rails test     # reproduit l'eager loading de la CI (révèle des erreurs invisibles sinon)
```

SimpleCov écrit un rapport dans `coverage/index.html` à chaque exécution.
Couverture actuelle : **environ 64 % des lignes** — l'objectif est 80 %.

La CI (`.github/workflows/ci.yml`) rejoue sur chaque push et chaque pull request :
RuboCop, Brakeman, `bundler-audit`, l'audit des paquets importmap, la suite de tests et les
seeds. Elle reprend les étapes de `config/ci.rb`, que `bin/ci` exécute en local.

## Déploiement

Heroku, application `cyrillepierre` :

```bash
git push heroku master
```

Les migrations tournent automatiquement grâce à la `release` phase du `Procfile`.

À savoir :

- `config.force_ssl` est actif ; `assume_ssl` doit **rester désactivé** sur Heroku, sinon la
  redirection HTTP → HTTPS ne se déclenche plus.
- Le disque Heroku est éphémère, d'où Cloudinary pour tous les fichiers.
- `/up` est le point de santé surveillé par UptimeRobot.
- L'app LinkedIn doit déclarer les deux URLs de callback, avec et sans `www`.

Le runbook DNS (rendre `https://cyrillepierre.com` sans `www` accessible) est dans
[`docs/runbook-dns-cloudflare.md`](docs/runbook-dns-cloudflare.md).

## Documentation interne

`CLAUDE.md` détaille l'architecture, les choix de conception et les pièges déjà rencontrés
(prompts du Studio, catalogue de réalisations, publication LinkedIn, page CV). À lire avant
toute modification du Studio.
