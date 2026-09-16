# rubocop:disable Layout/LineLength, Metrics/ModuleLength
module RealisationCatalog
  ITEMS = [
    { id: "N°01",
      scale: "PME-site / filiale GE (General Mills)",
      type_orga: "usine industrielle automatisée",
      context: "Yoplait (marque General Mills, GE mondial) · site Vienne · agroalimentaire · 200 personnes · 3 unités de production",
      titre: "Fusion des silos Production / Maintenance / Process",
      resultat: "+8% TRS · 480 K€/an · −30% aléas — résultat de SITE, produit par plusieurs chantiers menés de front (indicateurs de performance, routines quotidiennes et hebdomadaires, outils d'animation, fusion des silos, suivi des arrêts)",
      visual_hint: "Graphique en barres avant/après (57%→65%) avec une rangée d'icônes engrenage, personnes et " \
                   "poignée de main, et un encart montant en euros.",
      semantic_scope: "Huit points de TRS, c'est énorme en industrie : ce résultat n'est PAS attribuable à la seule fusion des silos. Il vient de chantiers simultanés dont la contribution individuelle n'est pas isolable — et qui ne produisent cet effet que pris ensemble. Ne jamais présenter ce chiffre comme le rendement d'une initiative isolée ; dire au contraire que c'est un résultat d'ensemble.",
      tags: %w[agro agroalimentaire TRS rendement performance silos management résultat-systémique],
      page: { company: "Yoplait · Vienne · 200 personnes · 3 unités",
              result: "+8% TRS · 480 K€/an · −30% aléas",
              icon: "fa-arrow-trend-up",
              description: "Rituels de pilotage fondés sur l'équité factuelle, binômes mixtes TPM sur le terrain. Les équipes ont cessé de se renvoyer la balle pour devenir acteurs de la performance. 480 000 € d'économies annuelles sur 3 unités." } },
    { id: "N°02",
      scale: "ETI (CENEXI, 400p, 3 sites)",
      type_orga: "usine industrielle process continu",
      context: "CENEXI (CMO pharma indépendant, 400 personnes, 3 sites) · site Fontenay-sous-Bois · lignes de remplissage aseptiques automatisées",
      titre: "Plan de réduction des rebuts sur 18 mois",
      resultat: "450 K€/an économisés",
      visual_hint: "Courbe en pointillés descendante (rebuts), une petite icône d'ampoule injectable, encart " \
                   "montant économisé.",
      tags: %w[pharma pharmaceutique rebuts qualité pertes SAP],
      page: { company: "CENEXI · Pharma aseptique · Fontenay-sous-Bois",
              icon: "fa-arrow-trend-down",
              description: "3,3 M€ de pertes identifiées via extraction SAP croisée sur 3 routines. 7 chantiers prioritaires pilotés conjointement avec McKinsey. Analyse fine par produit et machine, gains rapides sécurisés dès les premières semaines." } },
    { id: "N°03",
      scale: "PME-site / filiale GE (Campbell Soup Co.)",
      type_orga: "usine industrielle automatisée",
      context: "LIEBIG (marque Campbell Soup Company, GE mondial) · site Le Pontet · agroalimentaire · lignes de production automatisées",
      titre: "Digitalisation du pilotage de la performance (TRS)",
      resultat: "240 K€/an · −50% arrêts non identifiés",
      visual_hint: "Un écran/tablette avec des barres de progression (OEE en direct), encadré par une icône " \
                   "presse-papier se transformant en tablette.",
      tags: %w[agro agroalimentaire digital TRS OEE arrêts indicateurs tableau-de-bord],
      page: { company: "LIEBIG / Campbell · Le Pontet",
              icon: "fa-display",
              description: "Remplacement d'un suivi manuel par une solution tactile automatisée. Les opérateurs impliqués dans la conception — le désintérêt s'est transformé en culture de la responsabilité. +2% TRS, une heure de gestion libérée par manager chaque jour." } },
    { id: "N°04",
      scale: "PME-site / filiale GE (Campbell Soup Co.)",
      type_orga: "usine industrielle automatisée",
      context: "LIEBIG (marque Campbell Soup Company, GE mondial) · site Le Pontet · agroalimentaire · supply chain & production",
      titre: "Standardisation du packaging barquette",
      resultat: "400 K€ de gains · supply chain + production",
      visual_hint: "Petite grille de 6 boîtes ('Par 6') qui devient, via une flèche, une grille plus dense de " \
                   "8 boîtes ('Par 8'), icône carton.",
      tags: %w[agro agroalimentaire standardisation packaging flux supply-chain],
      page: { company: "LIEBIG / Campbell · Le Pontet",
              title: "Standardisation du packaging barquette (Par 6 → Par 8)",
              result: "400 K€ · 220 K€ packaging · 180 K€ supply chain",
              icon: "fa-boxes-stacked",
              description: "Projet transversal Production / Logistique / Commercial piloté en CODIR. 720 vs 768 briques par palette. Convaincre les commerciaux de renégocier leurs contrats clients — la partie la plus difficile." } },
    { id: "N°05",
      scale: "PME-site / filiale GE (Campbell Soup Co.)",
      type_orga: "usine industrielle automatisée",
      context: "LIEBIG (marque Campbell Soup Company, GE mondial) · site Le Pontet · 100 personnes · lignes automatisées",
      titre: "Organisation en Unités Autonomes de Production (UAP)",
      resultat: "TRS 57% → 67% · durées intervention ÷2",
      visual_hint: "Deux boîtes séparées (Production / Maintenance) qui fusionnent via une flèche en une seule " \
                   "boîte (UAP), encart TRS.",
      semantic_scope: "Pour : restructuration organisationnelle production/maintenance, création d'unités autonomes, amélioration TRS. NE PAS utiliser pour de l'animation d'équipe, de la motivation ou des rituels de management — utiliser N°16 pour ces sujets.",
      tags: %w[agro organisation UAP autonomie maintenance production TRS productivité capacité restructuration-orga],
      page: { company: "LIEBIG / Campbell · Le Pontet · 100 personnes",
              result: "TRS 57% → 67% · durées d'intervention ÷2",
              icon: "fa-people-group",
              description: "Intégration maintenance/production inspirée de STMicroelectronics. Résolution de problèmes en équipe, plus de renvoi de balle. Dès 2012, les lignes s'arrêtaient le vendredi AM — le week-end était libéré." } },
    { id: "N°06",
      scale: "ETI (CENEXI, 400p, 3 sites)",
      type_orga: "usine industrielle process continu",
      context: "CENEXI (CMO pharma, ETI 400p) · site Fontenay-sous-Bois · 170 personnes · production continue",
      titre: "Réduction de l'absentéisme de courte durée",
      resultat: "Absentéisme divisé par deux dès la 1ère année · +2 M ampoules/mois",
      visual_hint: "Deux calendriers mensuels côte à côte, avant (plusieurs cases rouges d'absence) vs après " \
                   "(presque aucune), icône médaille.",
      semantic_scope: "UNIQUEMENT : arrêts maladie répétés, absentéisme, présence au travail, éviter les intérimaires mal formés. NE PAS utiliser pour : gain de productivité, capacité, isopérimètre, départs en retraite, flux, organisation des postes.",
      tags: %w[pharma absentéisme arrêts-maladie présence engagement management intérimaires],
      page: { company: "CENEXI · Pharma aseptique · 170 personnes",
              result: "−10% absentéisme · +2 M ampoules/mois",
              icon: "fa-user-check",
              description: "30 entretiens de recadrage en 4 mois (sept–déc 2016). Plus de lignes arrêtées pour absence non planifiée. Records historiques de production dès le premier trimestre 2017 — +10% sur 3 mois consécutifs." } },
    { id: "N°07",
      scale: "PME-site / filiale GE (Campbell Soup Co.)",
      type_orga: "usine industrielle automatisée",
      context: "LIEBIG (marque Campbell Soup Company) · site Le Pontet · budget CAPEX 4 M€/an · industrie agroalimentaire",
      titre: "Plan Directeur CAPEX à 3 ans — 10 M€",
      resultat: "10 M€ planifiés · validé Direction Monde",
      visual_hint: "Une frise chronologique horizontale sur 3 ans avec 3 jalons et petites cartes projet, " \
                   "badge 'Direction Monde validée'.",
      tags: %w[agro CAPEX investissement stratégie direction],
      page: { company: "LIEBIG / Campbell · Le Pontet · CAPEX 4 M€/an",
              result: "10 M€ planifiés · présenté Direction Monde",
              icon: "fa-chart-gantt",
              description: "Groupes de travail Production / Maintenance / R&D / Marketing. Chiffrage enveloppe avec contingences, lissage financier sur 4 ans. Présentation en QBR à la Direction Europe et au Directeur Industriel Monde en avril 2011." } },
    { id: "N°08",
      scale: "PME-site / filiale GE (Campbell Soup Co.)",
      type_orga: "usine industrielle automatisée",
      context: "LIEBIG (marque Campbell Soup Company) · site Le Pontet · travaux neufs · industrie agroalimentaire",
      titre: "Mise aux normes HSE — LOTO, STEP, Bruit, Sprinklage",
      resultat: "930 K€ investis · conformité DREAL",
      visual_hint: "Rangée de 4 icônes sécurité (cadenas, goutte d'eau, haut-parleur, douche) avec un court " \
                   "libellé chacune, badge conformité.",
      tags: %w[HSE sécurité conformité réglementation travaux],
      page: { company: "LIEBIG / Campbell · Travaux Neufs & Services Généraux",
              result: "930 K€ investis · conformité DREAL · −10 dB",
              icon: "fa-shield-halved",
              description: "4 chantiers réglementaires menés en parallèle : consignation électrique LOTO, filtre tertiaire STEP 350 K€, TAR silencieuse 550 K€, baffles 30 K€. Mesure externe confirmée 10 dB sous la norme. Budget 3,5 M€/an géré." } },
    { id: "N°09",
      scale: "ETI (CENEXI, 400p, 3 sites)",
      type_orga: "usine industrielle process continu",
      context: "CENEXI (CMO pharma, ETI 400p) · site Fontenay-sous-Bois · 2 lignes de remplissage aseptiques automatisées",
      titre: "Organisation 7 jours/7 sur lignes aseptiques",
      resultat: "+500 000 ampoules/semaine",
      visual_hint: "Deux bandeaux calendrier hebdomadaire, avant (5 jours couverts) vs après (7 jours " \
                   "couverts), icône ampoule.",
      tags: %w[pharma capacité production organisation 7j7 weekend],
      page: { company: "CENEXI · Fab. Liquide Injectables · 2 lignes aseptiques",
              title: "Mise en place d'une organisation 7 jours/7 sur lignes aseptiques",
              icon: "fa-calendar-check",
              description: "Formations ZAC et aseptique en parallèle, recrutement de managers WE sur 8 semaines volontaires. 2 lignes en 48h produisent plus que 3 lignes en 24h. Négociation IRP validée, réduction de 10 ETP intérimaires dès septembre 2017." } },
    { id: "N°10",
      scale: "ETI/GE (client automobile)",
      type_orga: "industrie manufacturière",
      context: "Mission EFESO Consulting · sous-traitant automobile · intervention COMEX d'une structure ETI/GE",
      titre: "Plan de progrès avec un COMEX non aligné",
      resultat: "Mission signée · 4 mois terrain · COMEX converti",
      visual_hint: "Un organigramme simple : une boîte en haut (PDG) reliée à 3 boîtes en dessous (directeurs), " \
                   "badge 'mission signée'.",
      semantic_scope: "UNIQUEMENT pour : résistance au changement au niveau COMEX ou Direction, alignement stratégique entre dirigeants, plan de progrès avec des parties prenantes C-suite. NE PAS utiliser pour : coordination d'équipes terrain, management de proximité, animation des opérateurs — ce sont des défis fondamentalement différents.",
      tags: %w[auto automobile consulting COMEX changement résistance alignement-direction stratégie],
      page: { company: "EFESO Consulting · Sous-traitant automobile",
              icon: "fa-handshake",
              description: "Directeur Industriel contre la démarche imposée par son PDG. Création de confiance avec le CODIR du site, plan audible pour toutes les parties. Proposition validée en COMEX, mission de 2 j/semaine terrain + comités mensuels." } },
    { id: "N°11",
      scale: "Micro-entreprise (Cyrille seul, 1-3 personnes)",
      type_orga: "atelier artisanal / travail 100% manuel",
      context: "Centaur Bike · Lyon · micro-entreprise fondée et pilotée par Cyrille seul · 4 pivots en 4 ans : 2021 électrification vélos sur-mesure, 2022 reconditionnement + vente vélos électriques (pic 250 K€ CA, marge 39%), 2023 service mobile flottes professionnelles B2B, 2024 conseil Lean et organisationnel pour ateliers de reconditionnement vélos en libre-service",
      titre: "Création et pilotage d'une micro-entreprise avec 4 pivots stratégiques en 4 ans — de l'artisan au conseil",
      resultat: "4 pivots réussis · pic 250 K€ CA (2022) · passage du B2C artisanal au conseil B2B · 2ème prix pitch Rotary · capacité de remise en question et de réinvention permanente",
      visual_hint: "Frise horizontale à 4 points (2021-2024) avec une icône différente à chaque étape (prise " \
                   "électrique, recyclage, immeuble, graphique).",
      semantic_scope: "Pertinent pour : défis de création/démarrage TPE, pivots stratégiques, remise en question d'un modèle économique, développement commercial, structuration d'une petite organisation, conseil auprès d'ateliers de reconditionnement. Cyrille a vécu l'adaptabilité permanente en tant que dirigeant.",
      tags: %w[startup entrepreneuriat micro-entreprise TPE création pivot stratégie développement-commercial organisation reconditionnement vélo lean conseil adaptabilité réinvention B2B],
      page: { company: "Centaur Bike · Lyon · 2021–2024",
              title: "Création et pilotage de Centaur Bike — 4 pivots stratégiques en 4 ans",
              result: "pic 250 K€ (2022) · 2ème prix pitch Rotary",
              icon: "fa-arrows-rotate",
              pivots: [
                { year: "2021", text: "Électrification sur-mesure de vélos classiques" },
                { year: "2022", text: "Reconditionnement et vente de vélos électriques — pic 250 K€, marge 39%" },
                { year: "2023", text: "Service mobile pour flottes professionnelles B2B" },
                { year: "2024", text: "Conseil Lean et organisationnel pour ateliers de reconditionnement" }
              ] } },
    { id: "N°12",
      scale: "PME petite (Enjoué, association, 20-50 personnes)",
      type_orga: "atelier artisanal / travail 100% manuel / 20-50 personnes",
      context: "Projet RE-PLAY · Enjoué · Lyon · association loi 1901 · atelier de reconditionnement artisanal de jouets · 20-50 personnes · travail exclusivement manuel · mission de mécénat de compétences (en cours)",
      titre: "Digitalisation des processus d'un atelier de reconditionnement manuel — UX inclusive zero-text, Poka-Yoke numérique",
      resultat: "Application Rails déployée en production · 6 points de contrôle qualité numérisés · traçabilité AGEC · opérateurs guidés sans texte",
      visual_hint: "Maquette d'app mobile : photo d'un objet et une rangée de petites icônes rondes de " \
                   "contrôle qualité, un flux de 3 boîtes (dons → contrôle → stock qualifié).",
      semantic_scope: "UNIQUEMENT pour : ateliers artisanaux manuels, structures d'insertion ou ESS, reconditionnement, digitalisation d'un processus manuel simple. NE PAS utiliser pour une PME industrielle classique (agroalimentaire, pharma, mécanique…) sous prétexte qu'elle a 20 personnes — le contexte est fondamentalement différent.",
      tags: %w[tech digital application Rails atelier manuel reconditionnement inclusion qualité traçabilité ESS association poka-yoke zero-text],
      page: { company: "Re-Play · Enjoué · Application métier Rails",
              title: "Application de suivi qualité inclusive pour reconditionnement jouets",
              result: "Déployée en production · Traçabilité complète",
              icon: "fa-mobile-screen",
              description: "Interface ultra-visuelle sans mots pour salariés en insertion (illettrisme partiel). 6 paramètres qualité critiques par jouet. Flux hétérogènes de dons transformés en stock qualifié traçable. Performance industrielle ET inclusion sociale." } },
    { id: "N°13",
      scale: "PME petite (atelier artisanal, petite équipe)",
      type_orga: "atelier artisanal / travail 100% manuel",
      context: "Projet Démontés · Centaur Bike · Saint-Fons · atelier de reconditionnement manuel de pièces vélos · petite équipe artisanale",
      titre: "Industrialisation d'un atelier artisanal de reconditionnement : Lean 5S, standardisation des postes, SOP, formation",
      resultat: "16 rôles modélisés · postes 5S organisés · SOP rédigées · tutoriels vidéo · filière réemploi structurée",
      visual_hint: "Flux horizontal en 4 étapes avec icônes (collecte → tri → reconditionnement → pièces " \
                   "certifiées), petits badges méthode en dessous.",
      semantic_scope: "UNIQUEMENT pour : ateliers artisanaux manuels, structures sans process industriel formalisé, reconditionnement, économie circulaire. NE PAS utiliser pour une PME industrielle (agroalimentaire, pharma…) car le type de structure est différent malgré une taille similaire.",
      tags: %w[lean 5S VSM SOP atelier artisanal reconditionnement manuel organisation industrialisation éco-circulaire processus petite-équipe],
      page: { company: "Projet Démontés · Atelier SFAIRE · Centaur Bike",
              title: "Industrialisation d'un atelier de reconditionnement de pièces vélos",
              result: "16 rôles modélisés · Lean 5S · tutoriels vidéo",
              icon: "fa-recycle",
              description: "Transformation d'une intuition écologique en processus industriel structuré. Modélisation de la chaîne de valeur, 5S physique du site de production, 15+ tutoriels vidéo pour traçabilité AGEC et montée en compétences des opérateurs." } },
    { id: "N°14",
      scale: "ETI (GHM, 500 personnes)",
      type_orga: "industrie lourde / fonderie",
      context: "GHM (ETI, 500 personnes) · fonderie · Sommevoire · site industriel lourd",
      titre: "Conduite autonome d'un chantier de génie civil",
      resultat: "300 K€ budget · délais tenus · 100 K€/an",
      visual_hint: "Frise à 3 points (bureau d'étude → chantier → mise en service) avec petites cartes projet.",
      tags: %w[métallurgie fonderie génie-civil CAPEX travaux-neufs],
      page: { company: "GHM · Sommevoire · Ingénieur Travaux Neufs · 2003",
              result: "300 K€ budget · délais tenus · 100 K€/an économisés",
              icon: "fa-hard-hat",
              description: "Bureau d'étude interne, conception et automatisme d'une installation de retraitement de sable de fonderie. Deadline environnementale Agence de l'Eau fin 2005. Négociation prestataires, suivi de chantier avec petite structure locale — mis en service en octobre 2005." } },
    { id: "N°15",
      scale: "GE-site / filiale GE (STMicroelectronics, GE mondial)",
      type_orga: "industrie de haute technologie / salle blanche",
      context: "STMicroelectronics (GE mondial, semi-conducteurs) · site Crolles · 5 000 personnes sur site · salle blanche · production de semi-conducteurs",
      titre: "Management d'une équipe maintenance postée en salle blanche — TPM",
      resultat: "120 K€/an sur durée de vie équipements · 6 opérateurs managés · processus TPM structurés",
      visual_hint: "Un encadré 'salle blanche' avec 3 icônes à l'intérieur (microscope, engrenage, " \
                   "presse-papier), badges montant et échelle GE à côté.",
      tags: %w[semi-conducteurs maintenance TPM salle-blanche équipe-postée industrie-haute-tech GE],
      page: { company: "STMicroelectronics · Crolles · Salle blanche",
              result: "120 K€/an · processus TPM structurés",
              icon: "fa-microchip",
              description: "Chef d'équipe maintenance postée sur lignes CMP (polissage 300mm), site de 5 000 personnes. Rédaction des procédures préventives et correctives, banc de test modules maison, externalisation progressive de la réparation. Formation du sous-traitant et transfer de compétences." } },
    { id: "N°16",
      scale: "PME-site / filiale GE (Campbell Soup Co.)",
      type_orga: "usine industrielle automatisée",
      context: "LIEBIG (marque Campbell Soup Company, GE mondial) · site Le Pontet · agroalimentaire · 100 personnes",
      titre: "Refonte du management de proximité — formation et alignement des chefs d'équipe",
      resultat: "−40% de pannes · 850 K€/an d'économies · 6 000h gagnées (200 K€/an) · managers alignés · " \
                "0 tension syndicale",
      visual_hint: "Une icône manager centrale reliée par des traits à plusieurs icônes d'équipiers en dessous, " \
                   "comme un petit schéma en étoile.",
      tags: %w[agro management formation chefs-équipe alignement-terrain coordination-équipes animation-équipe DDS rituels-management management-visuel pilotage-terrain IRP développement-managers coaching management-de-proximité],
      page: { company: "LIEBIG / Campbell · Le Pontet · 100 personnes",
              result: "Managers alignés · ambiance assainie · 0 tension syndicale",
              icon: "fa-people-arrows",
              description: "Séminaire management de la performance co-animé : DDS, réactivité aux arrêts, passage de consignes, feedback positif. Réorganisation des équipes pour casser les liens de copinage. Un manager reconverti à sa demande, sans conflit. Montée en compétences interne." } },
    { id: "N°17",
      scale: "ETI/GE (SOGEFI, équipementier automobile)",
      type_orga: "industrie manufacturière / forge et traitement de surface",
      context: "SOGEFI (équipementier automobile, fabricant de barres de suspension) · mission EFESO Consulting · industrie automobile",
      titre: "Chantier WCM sur grenailleuse — groupe de travail pluridisciplinaire",
      resultat: "43 K€ économisés sur 3 mois · CAPEX 4 K€ · remise au standard · équipement fiabilisé",
      visual_hint: "Une boîte machine/engrenage à gauche, une flèche avec la méthode en label, une boîte " \
                   "résultat à droite.",
      tags: %w[auto automobile WCM chantier amélioration-continue pluridisciplinaire fiabilité équipement maintenance TPM forge traitement-surface],
      page: { company: "SOGEFI · Automobile · Mission EFESO Consulting",
              title: "Chantier WCM sur grenailleuse — groupe pluridisciplinaire",
              result: "43 K€ économisés sur 3 mois · CAPEX 4 K€",
              icon: "fa-gears",
              description: "Équipes lassées de la machine, problème renvoyé d'une équipe à l'autre. Groupe de travail pluridisciplinaire piloté par un manager production. Analyse historique, remise au standard, amélioration des buses de soufflage selon proposition du référent terrain. Défense CODIR réussie." } },
    { id: "N°18",
      scale: "PME-site / filiale GE (Campbell Soup Co.)",
      type_orga: "usine industrielle automatisée",
      context: "LIEBIG (marque Campbell Soup Company, GE mondial) · site Le Pontet · agroalimentaire · 100 personnes",
      titre: "Réduction de la consommation MO cariste — méthode ECRS",
      resultat: "−3 ETP intérimaires · dimensionnement accepté sans conflit social · ECRS appliqué",
      visual_hint: "Avant (deux icônes chariot élévateur) et après (une seule icône chariot) séparés par une " \
                   "flèche, badge vert 'sans conflit'.",
      tags: %w[agro ECRS MO optimisation-effectifs logistique-interne manutention productivité lean intérimaires],
      page: { company: "LIEBIG / Campbell · Le Pontet · Logistique interne",
              result: "−3 ETP intérimaires · accepté sans conflit social",
              icon: "fa-truck-fast",
              description: "2 caristes par équipe → 1 par rationalisation ECRS des tâches entre les deux ateliers. Démarche portée avec un manager syndiqué CFE-CGC, population intérimaire. La montée en performance des opérateurs a libéré du temps sans friction sociale." } },
    { id: "N°19",
      scale: "ETI (CENEXI, 400p, 3 sites)",
      type_orga: "usine industrielle process continu",
      context: "CENEXI (CMO pharma, ETI 400p) · site Fontenay-sous-Bois · 170 personnes · lignes de remplissage aseptiques",
      titre: "Mise en place de nouveaux horaires 3×8 — négociation IRP et volontariat",
      resultat: "−10 ETP intérimaires · volume maintenu · accord IRP signé · démarrage sur volontariat",
      visual_hint: "Un cadran d'horloge découpé en équipes (matin/après-midi/nuit) à côté d'un badge accord " \
                   "signé.",
      tags: %w[pharma horaires organisation 3x8 IRP négociation-sociale intérimaires changement volontariat],
      page: { company: "CENEXI · Pharma aseptique · 170 personnes",
              result: "−10 ETP intérimaires · accord IRP · volume maintenu",
              icon: "fa-clock-rotate-left",
              description: "Contraintes RERA, travaux autoroutiers nocturnes, besoin de recouvrement. Sondage terrain préalable pour lever les objections. Groupe de travail chefs d'équipe, horaires sur volontariat 8 semaines. Accord IRP signé début août, déploiement septembre 2017." } },
    { id: "N°20",
      scale: "ETI (CENEXI, 400p, 3 sites)",
      type_orga: "usine industrielle process continu",
      context: "CENEXI (CMO pharma, ETI 400p) · site Fontenay-sous-Bois · 170 personnes",
      titre: "Mise en place de la classification Leem et minima de salaire — fidélisation des opérateurs qualifiés",
      resultat: "Classification définie · minima salaires validés Direction · fidélisation renforcée en zone d'activité concurrentielle (bassin d'emploi où plusieurs employeurs se disputent les opérateurs qualifiés)",
      visual_hint: "Trois barres ascendantes de hauteurs différentes (niveaux C/B/A) à côté d'un badge " \
                   "fidélisation.",
      semantic_scope: "Pour : fidélisation, turn-over, attractivité salariale, grilles de classification. Le bassin d'emploi est CONCURRENTIEL — plusieurs employeurs se disputent les opérateurs qualifiés ; ne jamais le décrire comme un marché de l'emploi détendu.",
      tags: %w[pharma RH classification salaire fidélisation compétences convention-collective social emploi recrutement],
      page: { company: "CENEXI · Pharma aseptique · RH / Social",
              title: "Mise en place de la classification Leem et minima de salaire",
              result: "Classification validée · fidélisation opérateurs ZAC",
              icon: "fa-scale-balanced",
              description: "Opérateurs ZAC débauchés après 2-4 ans de formation. Vision des emplois par niveau ABC définie avec les chefs d'équipe, minima calculés et chiffrés. Intégration Leem 2018 anticipée, validation Direction décembre 2017. Turnover réduit sur les postes stratégiques." } },
    { id: "N°21",
      scale: "GE-site / filiale GE (STMicroelectronics, GE mondial)",
      type_orga: "industrie de haute technologie / salle blanche",
      context: "STMicroelectronics (GE mondial, semi-conducteurs) · site Crolles · 5 000 personnes · équipe postée 2×8 · salle blanche",
      titre: "Création d'un outil de passage de consignes en équipe postée",
      resultat: "Communication inter-équipes établie · problèmes récurrents tracés · bottleneck réduit",
      visual_hint: "Trois boîtes en ligne : icône équipe de nuit → icône tableau/graphique partagé → icône " \
                   "équipe de jour, reliées par des traits.",
      tags: %w[semi-conducteurs communication outil-digital passage-de-consignes équipe-postée traçabilité information partage],
      page: { company: "STMicroelectronics · Crolles · Équipe postée 2×8",
              result: "Communication inter-équipes établie · bottleneck réduit",
              icon: "fa-arrows-left-right",
              description: "Atelier CMP réputé problématique, bottleneck quotidien, problèmes récurrents perdus entre les équipes. Fichier Excel par machine et par jour, partagé par email à tous les postes et supports de journée. L'historique tracé permet des solutions durables et une escalade rapide." } },
    { id: "N°22",
      scale: "GE-site / filiale GE (STMicroelectronics, GE mondial)",
      type_orga: "industrie de haute technologie / salle blanche",
      context: "STMicroelectronics (GE mondial, semi-conducteurs) · site Crolles · lignes CMP 300mm · salle blanche",
      titre: "Banc de test et procédures de réparation pour modules de polissage",
      resultat: "100% bon du 1er coup · économies consommables et temps machine · diagnostic fiabilisé",
      visual_hint: "Une boîte 'diagnostic flou' avec une icône clé à outils, une flèche, puis une boîte avec " \
                   "un petit cadran/jauge à aiguille verte.",
      tags: %w[semi-conducteurs maintenance TPM salle-blanche procédures fiabilité banc-test diagnostic modules],
      page: { company: "STMicroelectronics · Crolles · Lignes CMP",
              result: "100% bon du 1er coup · économies consommables et temps machine",
              icon: "fa-gauge-high",
              description: "Diagnostic difficile entre défauts modules et partie commande machine. Rédaction des procédures préventives et correctives sur tous les modules CMP. Conception et assemblage du banc de test permettant de fiabiliser la réparation et de réduire les changements inutiles." } },
    { id: "N°23",
      scale: "GE-site / filiale GE (STMicroelectronics, GE mondial)",
      type_orga: "industrie de haute technologie / salle blanche",
      context: "STMicroelectronics (GE mondial, semi-conducteurs) · site Crolles · salle blanche · sous-traitance maintenance",
      titre: "Externalisation de la réparation des modules techniques",
      resultat: "Réparation totalement externalisée · techniciens ST libérés pour l'amélioration continue",
      visual_hint: "Trois boîtes en séquence : icône équipe interne → flèche en pointillés 'transfert' → " \
                   "icône sous-traitant → boîte résultat 'libéré'.",
      tags: %w[semi-conducteurs externalisation sous-traitance formation transfer-compétences maintenance optimisation-RH],
      page: { company: "STMicroelectronics · Crolles · Sous-traitance",
              icon: "fa-handshake",
              description: "Techniciens ST mobilisés sur réparation au lieu d'amélioration continue. Maîtrise complète des procédures, dimensionnement du stock, formation du référent sous-traitant en interne. Transfer progressif jusqu'à externalisation totale — avec amélioration continue apportée par le ST lui-même." } },
    { id: "N°24",
      scale: "PME-site / filiale GE (Campbell Soup Co.)",
      type_orga: "usine industrielle automatisée",
      context: "LIEBIG (marque Campbell Soup Company) · site Le Pontet · agroalimentaire · négociation internationale",
      titre: "Négociation et achat d'équipements industriels — support technique à l'acheteur Europe",
      resultat: "−5% objectif prix · intégré au Master Plan CAPEX 10 M€ · négociation anglais/IT/DE",
      visual_hint: "Trois petites icônes drapeaux reliées par des flèches bidirectionnelles, représentant une " \
                   "négociation internationale.",
      tags: %w[agro CAPEX négociation achats international fournisseurs technique investissement équipements],
      page: { company: "LIEBIG / Campbell · Négociation internationale",
              result: "−5% objectif prix · intégré au Master Plan CAPEX 10 M€",
              icon: "fa-euro-sign",
              description: "Négociation en anglais avec fournisseurs italiens et allemands selon les règles Campbell Europe. Complémentarité technique/achat : identification des points techniques permettant de baisser le prix ou changer de technologie. Approche gagnant-gagnant. Intégré au plan directeur à 3 ans." } },
    { id: "N°25",
      scale: "PME-site / filiale GE (Campbell Soup Co.)",
      type_orga: "usine industrielle automatisée",
      context: "LIEBIG (marque Campbell Soup Company) · site Le Pontet et BU Boulogne · 400 salariés · amphithéâtre",
      titre: "Présentation des résultats de l'unité aux salariés de l'équipe France",
      resultat: "400 salariés · présentation scène avec COMEX · compliment PDG · aisance reconnue",
      visual_hint: "Un amphithéâtre stylisé : plusieurs rangées courbes de petites icônes personnes face à " \
                   "une scène/icône micro en bas.",
      tags: %w[agro communication présentation scène COMEX amphithéâtre leadership visibilité résultats],
      page: { company: "LIEBIG / Campbell · Amphithéâtre · 400 salariés",
              result: "400 salariés · présentation scène avec le COMEX · compliment PDG",
              icon: "fa-microphone-lines",
              description: "Présentation sur scène en amphithéâtre devant 400 employés (site Le Pontet + BU Boulogne), aux côtés du COMEX France. Mise en valeur de l'équipe et des résultats de l'unité. Aisance reconnue par la Direction, compliment du PDG sur la prestation." } },
    { id: "N°26",
      scale: "ETI (CENEXI, 400p, 3 sites)",
      type_orga: "usine industrielle process continu",
      context: "CENEXI (CMO pharma, ETI 400p) · site Fontenay-sous-Bois · 170 personnes · pilotage MO",
      titre: "Mise en place d'indicateurs de suivi des consommations de main d'œuvre",
      resultat: "DLE 70% → 88% immédiat · commandes intérimaires pilotées en temps réel",
      visual_hint: "Deux jauges horizontales côte à côte, l'une majoritairement rouge (avant) et l'autre " \
                   "majoritairement remplie dans la couleur de marque (après).",
      tags: %w[pharma KPI indicateurs MO suivi intérimaires DLE pilotage-RH tableau-de-bord optimisation-effectifs],
      page: { company: "CENEXI · Pharma aseptique · Pilotage MO",
              title: "Mise en place d'indicateurs de suivi des consommations de MO",
              result: "DLE 70% → 88% · dès la mise en place",
              icon: "fa-chart-line",
              description: "Aucun suivi opérationnel des consommations intérimaires — DLE à 70%. Création d'un tableau Excel de suivi du nombre d'ETP nécessaires selon le planning de production, rempli par l'assistante administrative. Commandes intérimaires pilotées en temps réel. DLE à 88% immédiatement." } }
  ].freeze

  # La page /realisations, dans l'ordre d'affichage. Chaque réalisation doit figurer dans une
  # section et une seule ; l'ordre y est éditorial, pas celui des numéros. Un test le vérifie,
  # ainsi que la présence de l'illustration et des données de page pour chaque entrée.
  PAGE_SECTIONS = [
    { eyebrow: "Terrain", title: "Excellence opérationnelle",
      ids: %w[N°01 N°02 N°03 N°04 N°05 N°06 N°07 N°08 N°09 N°10 N°15 N°22 N°23 N°24] },
    { eyebrow: "Management & Organisation", title: "Équipes, structures, transformations RH",
      ids: %w[N°16 N°17 N°18 N°19 N°20 N°21 N°25 N°26] },
    { eyebrow: "Entrepreneuriat & Tech", title: "Créer, développer, déployer",
      ids: %w[N°11 N°12 N°13 N°14] }
  ].freeze

  # Ce que la page publique montre d'une réalisation : `page[:title]` et `page[:result]` ne sont
  # posés que quand la formulation publique diffère de celle du catalogue (plus courte, sans
  # les précisions destinées au modèle). `visual_hint` décrit l'illustration, qui vit dans le
  # partiel `pages/realisations/_nXX` — les trois se créent ensemble, jamais l'un sans l'autre.
  def self.page_title(item) = item.dig(:page, :title) || item[:titre]
  def self.page_result(item) = item.dig(:page, :result) || item[:resultat]
  def self.illustration_partial(item) = "pages/realisations/n#{item[:id].delete_prefix('N°')}"

  def self.find(id)
    ITEMS.find { |item| item[:id] == id }
  end

  # Le catalogue tel qu'un LLM doit le lire. Trois formes selon l'usage :
  # - :named      — titre, contexte (qui nomme l'entreprise) et résultat : lettres et propositions ;
  # - :anonymized — secteur et taille à la place du contexte : contenus publics (posts, actus) ;
  # - :detailed   — une fiche par réalisation avec tags, pour l'assistant de contact qui doit
  #                 choisir laquelle citer face à un visiteur.
  # Toutes portent le périmètre sémantique quand il existe : c'est lui qui interdit de rattacher
  # un chiffre au sujet voisin (l'absentéisme n'est pas de la productivité). Avant que le rendu
  # soit unique, le Studio l'oubliait — d'où des articles faux le 11/09/2026.
  PROMPT_STYLES = %i[named anonymized detailed].freeze

  def self.to_prompt(style)
    raise ArgumentError, "style inconnu : #{style.inspect}" unless PROMPT_STYLES.include?(style)

    entries = ITEMS.map { |item| public_send("#{style}_prompt_entry", item) }
    entries.join(style == :detailed ? "\n\n" : "\n")
  end

  def self.named_prompt_entry(item)
    "#{item[:id]} #{item[:titre]} — #{item[:context]} — #{item[:resultat]}#{semantic_scope_line(item, indent: 5)}"
  end

  def self.anonymized_prompt_entry(item)
    "#{item[:id]} #{item[:titre]} — #{item[:scale]}, #{item[:type_orga]} — #{item[:resultat]}#{semantic_scope_line(item, indent: 5)}"
  end

  def self.detailed_prompt_entry(item)
    [
      "#{item[:id]} [scale:#{item[:scale]}] [type:#{item[:type_orga]}] [tags:#{item[:tags].join(', ')}]",
      "  Contexte : #{item[:context]}",
      "  Réalisation : #{item[:titre]}",
      "  Résultat : #{item[:resultat]}"
    ].join("\n") + semantic_scope_line(item, indent: 2)
  end

  def self.semantic_scope_line(item, indent:)
    return "" if item[:semantic_scope].blank?

    "\n#{' ' * indent}⚠ Périmètre : #{item[:semantic_scope]}"
  end

  # Picks a realisation not present in exclude_ids, so that auto-generated posts (no
  # source provided) rotate through the catalogue instead of always citing the same ones.
  def self.pick_unused(exclude_ids: [])
    available = ITEMS.map { |item| item[:id] } - exclude_ids
    available = ITEMS.map { |item| item[:id] } if available.empty?
    available.sample
  end
end
# rubocop:enable Layout/LineLength, Metrics/ModuleLength
