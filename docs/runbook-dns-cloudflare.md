# Runbook — rendre `https://cyrillepierre.com` accessible

*Rédigé le 8 août 2026, à partir de l'état réel de la zone mesuré le même jour.*

## Le problème

`https://cyrillepierre.com` (domaine nu, sans `www`) **ne répond pas** : le port 443 ne
répond pas du tout, la connexion part en timeout.

```
$ curl -I https://cyrillepierre.com
curl: (28) Connection timed out
$ curl -I http://cyrillepierre.com
302 → http://www.cyrillepierre.com/
```

Le domaine nu pointe sur `192.64.119.5`, le service « URL Redirect » de Namecheap, qui ne
sait faire que du HTTP. Or les navigateurs modernes tentent HTTPS en premier : toute personne
qui tape `cyrillepierre.com` sans `www` — depuis une carte de visite, une signature d'email,
un CV papier — tombe sur une page d'erreur. Seul `www.cyrillepierre.com` fonctionne.

C'est le même piège que celui rencontré sur `costly.fr` en août 2026, à une différence près,
et elle est bonne : **DNSSEC n'est pas activé** sur ce domaine (aucun enregistrement DS,
`AD=false` chez un résolveur validant). Le piège n°1 de la migration `costly.fr` — changer les
serveurs de noms avec DNSSEC actif, ce qui met le domaine entier en panne, web et emails — ne
s'applique donc pas ici. À vérifier tout de même dans le panneau Namecheap avant de commencer.

## Inventaire de la zone avant toute modification

État constaté le 8 août 2026. **À recopier à l'identique dans Cloudflare, puis à vérifier
enregistrement par enregistrement contre cette liste.** Oublier les MX, c'est perdre les
emails.

| Type | Nom | Valeur | Priorité |
|---|---|---|---|
| NS | `cyrillepierre.com` | `dns1.registrar-servers.com` | — |
| NS | `cyrillepierre.com` | `dns2.registrar-servers.com` | — |
| A | `cyrillepierre.com` | `192.64.119.5` (redirection Namecheap — à supprimer) | — |
| CNAME | `www` | `synthetic-brushlands-ojakkl1lrihdjlfro8mph22b.herokudns.com` | — |
| MX | `cyrillepierre.com` | `eforward1.registrar-servers.com` | 10 |
| MX | `cyrillepierre.com` | `eforward2.registrar-servers.com` | 10 |
| MX | `cyrillepierre.com` | `eforward3.registrar-servers.com` | 10 |
| MX | `cyrillepierre.com` | `eforward4.registrar-servers.com` | 15 |
| MX | `cyrillepierre.com` | `eforward5.registrar-servers.com` | 20 |
| TXT | `cyrillepierre.com` | `v=spf1 include:spf.efwd.registrar-servers.com ~all` | — |

Absents et c'est normal : aucun sous-domaine de messagerie (`mail`, `imap`, `smtp`,
`autodiscover`, `autoconfig`), aucun DS (DNSSEC), aucun CAA, aucun `_dmarc`.

Les MX pointent vers le **transfert d'emails Namecheap**. ⚠️ Contrairement à ce que ce runbook
affirmait jusqu'au 16/09/2026, ce service **ne survit pas** à la délégation : Namecheap ne fait
de redirection d'emails qu'avec ses propres serveurs de noms, et son panneau *Redirect Email*
le dit en clair une fois les NS changés (« you must first change your nameservers to Namecheap
default »). Recopier les MX `eforward` dans Cloudflare ne sert donc à rien — ils pointent vers
des serveurs qui ne connaissent plus le domaine. Si une adresse du domaine doit recevoir du
courrier après la bascule, c'est **Email Routing** de Cloudflare (gratuit) qui la fournit, avec
ses propres MX et son propre SPF en remplacement.

## À vérifier d'abord : la piste légère

Avant de déléguer quoi que ce soit, regarder si Namecheap propose un enregistrement **ALIAS**
(ou ANAME) sur ce domaine, dans *Advanced DNS*. Un ALIAS résout le problème d'apex sans
toucher aux serveurs de noms :

1. Supprimer l'enregistrement `A` de redirection (`192.64.119.5`) et la règle *URL Redirect*.
2. Créer un `ALIAS` sur `@` vers `synthetic-brushlands-ojakkl1lrihdjlfro8mph22b.herokudns.com`.
3. Ajouter le domaine nu comme domaine personnalisé sur Heroku :
   `heroku domains:add cyrillepierre.com -a cyrillepierre`, puis vérifier que le certificat
   automatique le couvre (`heroku certs:auto -a cyrillepierre`).
4. Rediriger l'apex vers `www` côté application, ou laisser les deux servir le site.

Avantage : dix minutes, zéro risque pour les emails, aucun changement de serveurs de noms.
Inconvénient : Namecheap réserve l'ALIAS à certaines offres DNS selon les domaines — si
l'option n'apparaît pas, passer à Cloudflare ci-dessous. Cette voie n'a pas été testée sur ce
domaine, contrairement à la suivante.

## Voie recommandée : déléguer les DNS à Cloudflare (plan Free)

C'est le chemin déjà parcouru avec succès pour `costly.fr` en août 2026. Cloudflare sert le
HTTPS de l'apex et redirige vers `www`, ce que Namecheap ne sait pas faire.

1. **Créer le site dans Cloudflare** (plan Free). Cloudflare scanne la zone et l'importe.
   Vérifier l'import ligne par ligne contre le tableau ci-dessus, en particulier les cinq MX
   et leurs priorités.

2. **Supprimer** l'enregistrement `A` vers `192.64.119.5` et **créer** à sa place, sur `@`, un
   `CNAME` vers `synthetic-brushlands-ojakkl1lrihdjlfro8mph22b.herokudns.com` (Cloudflare
   autorise le CNAME à l'apex, c'est tout l'intérêt : il l'aplatit automatiquement).

3. **Régler le statut de proxy** :
   - `@` (apex) : **nuage orange**, proxifié — c'est Cloudflare qui doit servir le HTTPS et la
     redirection ;
   - `www` : **nuage gris**, DNS only — Heroku gère déjà son propre certificat pour ce nom ;
   - MX et TXT : pas de proxy possible, rien à faire.

4. **SSL/TLS → Full (strict)**.

5. **Créer la règle de redirection** avec le modèle **« Redirect from Root to WWW »** : 301,
   en cochant *Preserve query string*.

6. **Basculer les serveurs de noms chez Namecheap** vers ceux fournis par Cloudflare
   (*Domain → Nameservers → Custom DNS*), puis cliquer « Check nameservers now » dans
   Cloudflare.

7. **Vérifier**, une fois la propagation faite :

   ```bash
   curl -sS -o /dev/null -w "%{http_code} -> %{redirect_url}\n" https://cyrillepierre.com
   # attendu : 301 -> https://www.cyrillepierre.com/
   curl -sS -o /dev/null -w "%{http_code}\n" https://www.cyrillepierre.com
   # attendu : 200
   curl -sS -o /dev/null -w "%{http_code} -> %{redirect_url}\n" http://www.cyrillepierre.com
   # attendu : 301 -> https://www.cyrillepierre.com/   (force_ssl côté Rails)
   ```

   Puis **envoyer un email de test** à l'adresse du domaine et vérifier qu'il arrive. Ne pas
   considérer la bascule terminée avant cette vérification.

8. **Après 48 h de propagation** :
   - activer DNSSEC, côté Cloudflare cette fois, puis recopier l'enregistrement DS chez
     Namecheap. ⚠️ Les registrars ne demandent pas tous la même chose : OVH veut une
     **DNSKEY** (Key Tag / Flag 257 / Algorithme 13 / **clé publique**), Namecheap veut le
     **DS** (Key Tag / Algorithme / Digest Type 2 / **digest**). Mélanger les deux formes
     donne une chaîne invalide, donc un domaine en SERVFAIL — web *et* emails. Garder
     l'onglet du registrar ouvert pour pouvoir supprimer la clé en quelques secondes ;
   - envisager un **DMARC** (`_dmarc` en TXT, `p=none` pour commencer, en observation) ;
   - le **CAA** est facultatif, et plutôt à éviter ici (voir ci-dessous).

### Vérifier le DNSSEC après coup

Le DS met de quelques minutes à ~1 h à apparaître au registre. Deux faux positifs à
connaître pendant cette fenêtre, sinon on croit à tort avoir cassé la zone :

- **SERVFAIL transitoire** : les résolveurs ont encore en cache l'état non signé. Une vraie
  erreur de clé, elle, reste bloquée et fait tomber le site.
- **`www` en `AD=false`** : `www` est un CNAME vers `herokudns.com`, une zone **non signée**.
  Le CNAME est bien signé chez nous, mais les adresses finales viennent d'une zone qui ne
  l'est pas, donc la réponse complète ne peut pas être marquée authentifiée. Normal, rien à
  corriger — c'est l'apex et les MX qui doivent afficher `AD=true`.

```bash
# DS publié au registre ?
curl -s "https://dns.google/resolve?name=DOMAINE&type=DS" | python3 -m json.tool
# validation effective (Status=0 et AD=true attendus sur l'apex et les MX)
curl -s "https://dns.google/resolve?name=DOMAINE&type=MX"
# le résolveur valide-t-il vraiment ? (doit répondre Status=2 / SERVFAIL)
curl -s "https://dns.google/resolve?name=dnssec-failed.org&type=A"
```

### CAA : pourquoi on s'abstient

La tentation est de n'autoriser que les deux AC visibles (Let's Encrypt pour Heroku ACM,
Google Trust Services pour Cloudflare). C'est **trop étroit** : Cloudflare fait tourner les
autorités de son Universal SSL (GTS, mais aussi Let's Encrypt, SSL.com, DigiCert selon les
moments), et un CAA restrictif casse un renouvellement des mois plus tard, sans alerte.
Piège jumeau : ne **jamais** poser `issuewild ";"` pour interdire les wildcards — l'Universal
SSL de Cloudflare couvre `*.domaine`, ça bloquerait son renouvellement.

Sur un domaine dont tous les certificats sont émis automatiquement par Cloudflare et Heroku,
le CAA apporte peu et son mode d'échec est différé et silencieux. Si on en veut un malgré
tout, couvrir les quatre AC possibles, en `issue` **et** `issuewild` :

```
0 issue "letsencrypt.org"   0 issuewild "letsencrypt.org"
0 issue "pki.goog"          0 issuewild "pki.goog"
0 issue "ssl.com"           0 issuewild "ssl.com"
0 issue "digicert.com"      0 issuewild "digicert.com"
```

### DMARC : l'adresse `rua` doit être sur le domaine

`rua=mailto:...@gmail.com` ne fonctionne pas : la RFC 7489 §7.1 impose, pour une destination
hors domaine, une autorisation publiée dans la zone du destinataire
(`DOMAINE._report._dmarc.gmail.com`) — impossible chez Gmail. Google et Microsoft vérifient
cette règle et n'envoient alors aucun rapport. Utiliser une adresse **du domaine lui-même**
(`contact@domaine` ou un alias `dmarc@domaine` redirigé vers la boîte réelle), ce qui évite
au passage d'exposer une adresse personnelle dans un enregistrement DNS public.

Vérifier la valeur dans le DNS et pas seulement à l'écran du panneau — une coquille du type
`@domaine.f` au lieu de `@domaine.fr` passe inaperçue dans une colonne tronquée :

```bash
curl -s "https://dns.google/resolve?name=_dmarc.DOMAINE&type=TXT"
```

## Une fois l'apex joignable

Deux choses à reprendre côté application :

- L'app LinkedIn doit déclarer les **deux** URLs de callback,
  `https://cyrillepierre.com/auth/linkedin/callback` et
  `https://www.cyrillepierre.com/auth/linkedin/callback` : l'URL générée par Rails suit le host
  réellement utilisé, et une seule des deux déclarée donne l'erreur
  « redirect_uri does not match ».
- Ajouter un monitor **UptimeRobot** sur `https://cyrillepierre.com/up` en plus de celui sur
  `www`, pour être prévenu si l'apex retombe.

## Journal — étapes J+2 réalisées le 16 septembre 2026

Cinq semaines après la bascule au lieu de deux jours, sans conséquence. État vérifié avant de
commencer : zone saine, apex en 301 vers `www`, mais aucune DNSKEY, aucun DS, aucun `_dmarc`.

**DMARC** — posé via **Email → DMARC Management** de Cloudflare plutôt qu'à la main. L'outil
ajoute au TXT `_dmarc` une adresse de rapport hébergée par Cloudflare
(`<empreinte>@dmarc-reports.cloudflare.net`), autorisée dans sa propre zone comme l'exige la
RFC 7489 §7.1 : le problème de l'adresse `rua` hors domaine disparaît, et les rapports se
lisent dans le tableau de bord au lieu d'arriver en XML. Deux détails d'interface : l'outil
**complète la réponse DNS à la volée** — le panneau *DNS → Records* montre l'enregistrement
stocké, les résolveurs voient l'adresse Cloudflare ajoutée devant ; et il affiche un
avertissement « no default RUA found » pendant quelques minutes après l'activation, simple
retard de relecture. L'adresse `dmarc@cyrillepierre.com` saisie d'abord a été retirée du TXT :
elle n'existe pas (voir l'inventaire, les `eforward` sont morts). Valeur finale :

```
v=DMARC1; p=none; rua=mailto:c7867c6888b34422a6abc4c2af10d8da@dmarc-reports.cloudflare.net
```

Comme aucun courrier légitime ne part du domaine — l'application envoie depuis Gmail — la cible
raisonnable après quelques semaines d'observation est `p=reject`.

**DNSSEC** — *DNS → Settings → Enable DNSSEC* côté Cloudflare, puis *Advanced DNS → DNSSEC →
Add new* chez Namecheap avec Key Tag `2371`, Algorithm `13`, Digest Type `2`, Digest
`F2EBFE80DB62D9A7533827A41881A09FC8B8077EEA0AD0AAF9BB3264B903508E`. Le DS a été recalculé
localement à partir de la DNSKEY publiée (flag 257) avant la saisie, pour comparer à ce que
le panneau affichait — script Python de quelques lignes, key tag RFC 4034 + SHA-256 de
`owner + rdata`. Verisign a publié le DS en **moins d'une minute** ; `AD=true` sur l'apex, les
MX et `www` dès la première requête, aucun SERVFAIL transitoire observé. Le point Quad9 sur le
port 5053 ne répond pas depuis cette machine, ne pas l'utiliser pour vérifier.

**CAA** — non posé, conformément à la section ci-dessus.

**Email Routing** — activé dans la foulée pour remplacer les `eforward` morts, depuis la vue
*compte* (Email Service → Email Routing → *Onboard Domain*), la zone n'affichant pas l'entrée
dans son menu Email. L'assistant liste les enregistrements qu'il va poser mais **ne supprime
pas les conflits** : il faut retirer soi-même, dans *DNS → Records*, les MX étrangers et
l'ancien SPF (deux SPF sur un nom = erreur permanente), puis revenir cliquer *Activate*.
Il pose trois MX `route1/2/3.mx.cloudflare.net`, le SPF `v=spf1 include:_spf.mx.cloudflare.net
~all` et une clé DKIM `cf2024-1._domainkey`. Ensuite, sur la page du domaine, onglet *Routing
rules* : `contact@cyrillepierre.com` → Gmail de Cyrille, catch-all laissé sur *Drop* (sinon
tout `*@cyrillepierre.com` arrive, spam compris). Réception seulement, rien ne change à l'envoi.

⚠️ **Le test « je m'envoie un mail depuis Gmail » ne prouve rien** : Gmail déduplique un message
qui lui revient et ne l'affiche pas en réception. Cloudflare envoie alors une notification
« Missing email from … » qui explique exactement cela — ce n'est pas une erreur de remise.
Tester depuis une autre adresse, ou lire l'onglet *Activity log*.

**Envoi depuis Gmail « en tant que » `contact@`** — configuré le 16/09/2026 : Gmail → Comptes et
importation → « Envoyer des e-mails en tant que », serveur `smtp.gmail.com`, port 587, TLS,
identifiant = l'adresse Gmail, mot de passe = un **mot de passe d'application** dédié (Gmail
pré-remplit le formulaire avec `route1.mx.cloudflare.net`, qui ne sait pas envoyer : à
remplacer). Le code de confirmation arrive sur `contact@` via Email Routing. Cocher « Répondre
avec l'adresse à laquelle le message a été envoyé ».

Vérifié à la réception (*Afficher l'original*) : **SPF PASS pour `gmail.com`, aucun DKIM,
DMARC FAIL** pour `cyrillepierre.com`. Gmail envoie avec une enveloppe `gmail.com` et ne signe
pas pour un domaine étranger : rien n'est aligné. Sans conséquence en `p=none` (mail reçu en
boîte de réception), mais ajouter `_spf.google.com` au SPF **ne changerait rien**, l'enveloppe
n'étant pas sur le domaine.

**Reste ouvert** : `p=reject` est **exclu tant que l'envoi passe par Gmail**. Pour un DMARC
aligné, il faut un serveur qui signe DKIM pour `cyrillepierre.com`, branché dans ce même écran
Gmail à la place de `smtp.gmail.com` : Google Workspace, ou un relais gratuit (Brevo, SMTP2GO)
avec sa clé DKIM posée dans la zone. À faire le jour où un DMARC strict devient nécessaire.
