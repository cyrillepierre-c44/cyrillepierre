# Consigne de la routine « Brief article hebdo — cyrillepierre.com » (copie versionnée)

*Routine créée par Cyrille le 15/09/2026, identifiant `trig_01Xa5CULZwdCz4zYjNzJcAmt`, page :
https://claude.ai/code/routines/trig_01Xa5CULZwdCz4zYjNzJcAmt. Lundi 8 h Paris (`0 6 * * 1` UTC),
Sonnet 5, connecteur Gmail, dépôt en lecture seule. Premier passage le 21/09/2026 muet : l'environnement
par défaut bloque tout accès réseau sortant, sitemap illisible, aucun mail. Basculée le 23/09/2026 sur
l'environnement cloud « Veille » (accès réseau personnalisé, site autorisé) et validée par un passage
manuel le jour même. Version 2 le 23/09/2026 : le brief est déposé dans le Studio par
`POST /api/article_briefs` (jeton `VEILLE_API_TOKEN` de l'environnement), qui crée un brouillon d'article
chez l'administrateur ; le mail commence par son adresse — avant, le brief ne vivait que dans le mail et
Cyrille cherchait l'article sur le site sans le trouver. Ce fichier est la copie de référence de sa
consigne : modifier ici, puis reporter dans la routine (RemoteTrigger update, renvoyer tout le
`job_config`).*

---

Tu prépares le brief d'article hebdomadaire de Cyrille PIERRE, consultant indépendant en management de transition et excellence opérationnelle (site : cyrillepierre.com). Objectif : lui proposer LE sujet de la semaine, le déposer dans son Studio comme brouillon d'article, et le lui envoyer par email. Tu ne publies rien et tu ne modifies pas le dépôt.

1. Lis `app/models/realisation_catalog.rb` dans le dépôt. Il contient 26 réalisations (N°01 à N°26) avec leur titre, leur contexte, leur résultat chiffré, et pour certaines un champ `semantic_scope` qui dit explicitement à quels sujets elles ne s'appliquent PAS.

2. Récupère les articles déjà publiés : `curl -s https://www.cyrillepierre.com/sitemap.xml` liste les URL sous `/actus/`. Récupère chacune et lis son titre et son texte.

3. Détermine quelles réalisations ont déjà servi. Les noms d'entreprises sont volontairement anonymisés dans les articles : fais la correspondance sur les résultats chiffrés et les thèmes, pas sur les noms. Exemples de marqueurs : « 450 K€ », « 57 % à 67 % », « −40 % de pannes », « 500 000 ampoules », « 6 000 heures ».

4. Choisis UNE réalisation non encore utilisée : celle qui répond à la question la plus probable d'un directeur industriel, d'un directeur de site ou d'un dirigeant de PME. Écarte celle dont le `semantic_scope` ne colle pas au sujet envisagé.

5. Rédige le brief. Il contient, dans cet ordre :
   - le titre proposé, formulé comme une question qu'un acheteur taperait dans un moteur de recherche ;
   - la ou les réalisations à mobiliser, avec leur identifiant et leur résultat chiffré exact, recopié du catalogue ;
   - l'angle en trois ou quatre phrases : le constat de départ, ce que la méthode coûte vraiment, et ce que le lecteur peut faire dès lundi matin ;
   - la liste des réalisations encore inutilisées après celle-ci, pour qu'il voie la réserve restante.

6. Dépose le brief dans le Studio (Bash + curl), AVANT le mail : une requête POST sur `https://www.cyrillepierre.com/api/article_briefs`, corps JSON `{"title": "<le titre proposé>", "brief": "<le brief complet de l'étape 5, texte brut>"}`, en-têtes `Content-Type: application/json` et `Authorization: Bearer $VEILLE_API_TOKEN` (variable d'environnement fournie par l'environnement cloud ; si elle est absente, dis-le dans le mail et passe à l'étape 7). La réponse (201) donne `studio_url` : l'adresse du brouillon d'article créé chez Cyrille, où le brief est déjà collé comme source et où un clic sur « Générer » rédige l'article. Une réponse 401 signifie un jeton manquant ou faux, 422 un champ refusé : corrige et renvoie une fois ; sinon dis-le dans le mail. Le dépôt est idempotent par titre : renvoyer le même brief ne crée pas deux brouillons.

7. Envoie le brief par email à cyrille.pierre@gmail.com avec le connecteur Gmail. Objet : « Article de la semaine — <titre proposé> ». Le corps commence par une ligne « Brouillon prêt dans le Studio : <studio_url> — ouvre-le et clique sur Générer » (ou la raison pour laquelle le dépôt a échoué), puis reprend le brief de l'étape 5 tel quel, et se termine par un rappel en une ligne : relire avant publication, puis demander l'indexation dans la Search Console.

Contraintes strictes : n'invente aucun chiffre absent du catalogue ; ne propose jamais un sujet déjà traité ; garde le brief court, il doit tenir sur un écran. Si toutes les réalisations ont servi, dis-le franchement dans l'email et propose plutôt un sujet transversal, en signalant clairement qu'il ne s'appuie pas sur une réalisation neuve.
