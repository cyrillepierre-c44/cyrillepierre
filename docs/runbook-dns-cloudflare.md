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

Les MX pointent vers le **transfert d'emails Namecheap**. Ce service est lié au registrar, pas
aux serveurs de noms : il continue de fonctionner après une délégation à Cloudflare, à
condition de recréer les MX et le SPF à l'identique.

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
