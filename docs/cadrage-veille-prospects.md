# Cadrage — veille de signaux d'affaires, version de test

*Rédigé le 16 septembre 2026. Durée du test : deux semaines après mise en service.
Décision à la fin : continuer, élargir ou arrêter.*

## L'hypothèse à tester

Des entreprises industrielles d'Auvergne-Rhône-Alpes laissent des traces publiques du moment où
elles auraient besoin de Cyrille — sans le savoir ni le chercher. Un agent peut les repérer,
les trier, et ne remonter que celles qui valent une approche spontanée.

Ce qu'on ne teste **pas** : la surveillance en continu. Un condensé hebdomadaire suffit à
vérifier si les signaux valent quelque chose, et c'est le tri qui coûte du temps humain, pas
la collecte.

## Critère de succès, fixé avant de commencer

À la fin des deux semaines :

- au moins **trois fiches par semaine** jugées « à contacter » par Cyrille après lecture, sur
  au plus dix remontées ;
- au moins **un contact réellement envoyé** ;
- moins de **vingt minutes** de lecture du condensé le lundi.

En dessous, on arrête ou on change de sources. Le but n'est pas d'avoir un bel outil.

## Périmètre

| Axe | Retenu |
|---|---|
| Géographie | Auvergne-Rhône-Alpes d'abord, Île-de-France et vallée du Rhône en second |
| Secteurs | agroalimentaire, pharmaceutique, mécanique et métallurgie, microélectronique, plasturgie, reconditionnement |
| Taille | PME et ETI de 50 à 500 personnes, sites industriels de groupes |
| Exclus | BTP, logistique pure, services, entreprises en procédure collective (voir plus bas) |

## Les signaux, et ce qu'ils veulent dire

Un signal ne vaut que par le **moment** qu'il révèle. Une entreprise en redressement n'achète
pas de conseil ; une entreprise qui vient d'annoncer une extension, si.

| Signal | Lecture | Offre concernée | Poids |
|---|---|---|---|
| Offre d'emploi : directeur de site, directeur ou responsable de production | Poste vacant, souvent depuis des semaines : un manager de transition fait le pont | Transition | fort |
| Offre d'emploi : responsable amélioration continue, Lean, méthodes, maintenance | L'entreprise a identifié un chantier et cherche à l'internaliser | Excellence opérationnelle | fort |
| Cabinet de management de transition publiant une mission industrielle | Besoin explicite, payeur identifié | Transition | fort |
| Presse : extension, nouvelle ligne, investissement, relocalisation | Montée en cadence à organiser | Excellence opérationnelle, organisation | moyen |
| Presse : rappel produit, incident qualité, non-conformité | Chantier qualité et rebuts | Excellence opérationnelle | moyen |
| Presse : plan social, restructuration | Réorganisation à conduire — mais l'entreprise passera par un cabinet | Transition, via cabinet | faible |
| BODACC : changement de dirigeant, transfert de siège | Transition de gouvernance | Transition | faible |
| BODACC : sauvegarde, redressement | Trop tard pour du conseil | Exclu | nul |

Le score s'appuie sur le catalogue de réalisations : un signal proche d'une réalisation
chiffrée de Cyrille pèse plus qu'un signal générique, parce que l'approche pourra citer un cas
comparable — c'est ce qui la distingue d'une prospection ordinaire.

## Sources de la version de test

Test du 16/09/2026 sur Indeed, quatre requêtes en région lyonnaise et Auvergne-Rhône-Alpes :
une dizaine de vrais postes de direction (Medtronic, Mersen, LIMATEC, LYNKUS, MAPEI, SDEZ…),
dont plusieurs **ouverts depuis deux à quatre mois**. La requête « manager de transition » ne
rend que du bruit : les cabinets ne publient pas là.

**Règle tirée du test — l'ancienneté de l'annonce est le premier critère de score.** Un poste
de direction de production ouvert depuis plus de six semaines, c'est une usine qui tourne sans
son pilote. Aucune interprétation nécessaire.

| Source | Rôle | Accès | Statut |
|---|---|---|---|
| **Indeed** | Postes de direction de production, opérations, amélioration continue | Pas d'API publique. Soit un agent Claude planifié (connecteur Indeed, chaque lundi) qui produit le condensé sans rien développer dans le site, soit un agrégateur ci-dessous | Source principale |
| **Adzuna ou Jooble** | Agrégateurs avec API gratuite sur inscription ; reprennent une large part d'Indeed, HelloWork et APEC | Clé gratuite | À vérifier sur un échantillon avant de choisir |
| **France Travail** | Son propre fonds vise surtout opérateurs et techniciens, mais l'API relaie les « offres partenaires » (origine indiquée par offre) | Compte gratuit francetravail.io | Recoupement, une heure d'essai |
| **Cabinets de management de transition** | Missions industrielles publiées : Valtus, Delville, X-PM, Wayden, Robert Half | Une dizaine de pages lues une fois par semaine | Retenu |
| **Alertes Google en RSS** + Bref Eco, L'Usine Nouvelle, Les Echos région | Presse : extension, investissement, incident qualité, restructuration | Flux gratuits | Retenu |
| **BODACC** | Changement de dirigeant ; exclure les procédures collectives | API Opendatasoft, sans clé | Retenu, poids faible |

**Écartés** : APEC en direct (pas d'API, mais repris par les agrégateurs et France Travail) ;
Cadremploi (ni API ni flux, collecte interdite par ses conditions) ; **LinkedIn** (conditions
et absence de droit de lecture avec les accès actuels). Source la plus riche, LinkedIn reste
manuelle.

## Chaîne technique, dans le site existant

Rien de nouveau à héberger : le pipeline prospect, Solid Queue, le mailer et l'accès au LLM
sont déjà en place.

1. **`ProspectWatchJob`**, planifié dans `config/recurring.yml` le lundi à 6 h, production
   seulement, comme `ProspectPurgeJob`.
2. **Un collecteur par source** (`Watch::AggregatorSource` pour Adzuna ou Jooble,
   `Watch::FranceTravailSource`, `Watch::RssSource` pour la presse et les cabinets,
   `Watch::BodaccSource`), chacun rendant des signaux normalisés : entreprise, lieu, type,
   texte, adresse source, **date de publication**.
   Variante sans développement pour Indeed : un agent Claude planifié qui interroge le
   connecteur et envoie le condensé, à retenir si l'agrégateur ne couvre pas assez.
3. **Dédoublonnage** dans une table `watch_signals` (empreinte entreprise + type + semaine) :
   un signal déjà vu n'est jamais remonté deux fois. Sans cette table, chaque lundi
   recréerait les mêmes fiches.
4. **`SignalScorer`** : un appel Gemini par lot, avec le catalogue rendu par
   `RealisationCatalog.to_prompt(:named)` comme grille, la table des signaux ci-dessus comme
   consigne, et l'interdiction habituelle d'inventer un chiffre. Sortie : score, lecture en
   une phrase, réalisation comparable, brouillon d'accroche de trois lignes.
5. **Création d'au plus cinq fiches `Prospect`** par semaine, source `veille` (nouvelle
   valeur de l'enum), statut `en_veille`, avec le résumé, le lien source et le brouillon
   dans les notes. Les autres signaux restent dans `watch_signals`, consultables.
6. **Condensé du lundi** par mail à la boîte Gmail, cinq fiches, chacune avec son lien vers
   `/studio/prospects/:id`. Depuis la fiche, le bouton « Rédiger une proposition » existe déjà.

Tests : chaque collecteur testé sur des réponses enregistrées (WebMock, comme le reste de la
suite), le scorer sur un lot fixe, le job sur le dédoublonnage et le plafond de cinq.

Coût : une à deux journées de développement, quelques centimes de LLM par semaine.

## Ce que le RGPD impose, et qu'on fait dès la version de test

- La prospection B2B sur des données professionnelles publiques est licite sans consentement
  préalable (intérêt légitime, doctrine CNIL), à condition d'informer et de permettre
  l'opposition.
- **Article 14** : quand les données ne viennent pas de la personne, elle doit être informée au
  plus tard au premier contact. Le premier mail dira donc d'où vient l'information (« j'ai lu
  votre annonce sur France Travail », « j'ai vu dans Bref Eco que… »). C'est aussi ce qui rend
  l'approche crédible.
- La politique de confidentialité mentionnera cette collecte indirecte et ses sources, avec
  la même durée de conservation de trois ans que le reste du pipeline.
- Minimisation : on ne stocke que ce qui sert à qualifier le signal, jamais de données sur
  des personnes physiques autres que le dirigeant nommé publiquement.

## Le levier financier — phase 2, pas dans le test

L'outil d'analyse financière construit pendant l'ICCF peut lire les comptes annuels publics
(INPI, gratuits pour les sociétés qui n'ont pas opté pour la confidentialité) et en tirer
forces et faiblesses. Deux usages, de valeur inégale :

- **Pour analyser et choisir** : le meilleur. Une marge d'EBITDA qui s'érode, un BFR qui gonfle
  avec les stocks, des CAPEX sans effet sur le chiffre d'affaires sont des symptômes financiers
  de causes opérationnelles — TRS, rebuts, flux, organisation — que Cyrille sait traiter. C'est
  le pont entre le langage du décideur et le terrain, et c'est exactement ce que l'ICCF devait
  apporter. Il sert aussi à écarter : une entreprise sans trésorerie ne paiera pas.
- **Pour intéresser** : avec prudence. Un dirigeant connaît ses chiffres et n'aime pas qu'un
  inconnu les lui récite. Le diagnostic ne s'envoie jamais à froid ; il fonde une **hypothèse
  en une phrase**, posée comme une question, et il devient le contenu du premier rendez-vous.

Limites à connaître : comptes vieux de douze à dix-huit mois ; sites de groupes sans comptes
propres (Yoplait à Vienne n'a pas de bilan, General Mills France en a un) ; option de
confidentialité fréquente chez les petites sociétés. Les cibles naturelles de Cyrille, PME et
ETI indépendantes, publient en général.

Pendant le test, l'enrichissement financier reste **manuel** sur les cinq fiches de la
semaine : télécharger les comptes sur l'INPI, les importer dans l'outil, lire l'analyse avant
d'écrire l'approche. Si le test est concluant, la phase 2 automatise ce circuit.

## Calendrier

| Quand | Quoi |
|---|---|
| Semaine 1 | Développement : collecteurs, scorer, job, mail, tests. Mise à jour de la politique de confidentialité. |
| Lundi suivant | Premier condensé. Lecture, notation à la main de chaque remontée (pertinent / hors sujet / trop tard). |
| Deux lundis plus tard | Bilan contre le critère de succès. Décision. |
