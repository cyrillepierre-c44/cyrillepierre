require "net/http"

class ContactsController < ApplicationController
  def new
  end

  def infer_company
    company = params[:company].to_s.strip
    return render json: { sector: nil, size: nil } if company.blank?

    messages = [
      { role: "system", content: "Tu identifies des entreprises. Réponds uniquement en JSON valide, sans texte autour." },
      { role: "user", content: <<~PROMPT }
        Pour l'entreprise "#{company}", identifie UNIQUEMENT :
        1. Le secteur d'activité principal (ex : agroalimentaire, pharmaceutique, automobile, services numériques, etc.)
        2. L'effectif approximatif (ex : "~200 personnes", "2 000-5 000 personnes") — laisse null si inconnu

        Si l'entreprise est inconnue ou le nom trop générique, réponds : null

        Sinon, réponds uniquement avec ce JSON (rien d'autre) :
        {"secteur": "...", "effectif": "..."}
      PROMPT
    ]

    result = call_llm(messages).strip
    if result.downcase == "null" || result.blank?
      render json: { sector: nil, size: nil }
    else
      parsed = JSON.parse(result)
      render json: { sector: parsed["secteur"].presence, size: parsed["effectif"].presence }
    end
  rescue JSON::ParserError
    render json: { sector: nil, size: nil }
  end

  def chat
    message = params[:message].to_s.strip
    history = params[:history] || []
    themes  = params[:themes]  || []
    initial = params[:initial].to_s == "true"
    sector  = params[:sector].to_s.strip
    size    = params[:size].to_s.strip

    messages = [{ role: "system", content: build_system_prompt(themes, sector, size) }]
    history.each { |m| messages << { role: m["role"], content: m["content"] } }
    messages << { role: "user", content: initial ? "__START__" : message }

    reply = call_llm(messages)
    render json: { reply: reply, ready: reply.include?("##READY##") }
  end

  def summarize
    history = params[:history] || []
    themes  = params[:themes]  || []
    sector  = params[:sector].to_s.strip
    size    = params[:size].to_s.strip

    contexte_connu = []
    contexte_connu << "Secteur : #{sector}" if sector.present?
    contexte_connu << "Effectif : #{size}"  if size.present?
    contexte_line = contexte_connu.any? ? contexte_connu.join(" — ") : nil

    messages = [
      { role: "system", content: "Tu rédiges des résumés structurés de demandes clients. Réponds en français." },
      *history.map { |m| { role: m["role"], content: m["content"] } },
      {
        role: "user",
        content: <<~PROMPT
          Tu es un analyste expert. À partir de la conversation ci-dessus, rédige un résumé en Markdown pour Cyrille PIERRE, consultant.
          Thèmes sélectionnés : #{themes.join(", ")}.
          #{contexte_line ? "Données vérifiées sur l'entreprise : #{contexte_line}." : ""}

          CONSIGNES :
          - Corrige les artefacts de saisie vocale évidents : si un mot est phonétiquement proche d'un terme métier connu (ex : "île manufacturing" → "Lean Manufacturing", "trs" → "TRS", "capex" → "CAPEX"), utilise le terme correct sans le mentionner
          - Ne reformule PAS ce qui a été dit mot pour mot : SYNTHÉTISE et ANALYSE
          - Identifie les signaux forts (tension, croissance, blocage, ce qui a déjà été tenté)
          - Utilise un vocabulaire métier précis (Lean, 5S, flux, capacité, management visuel, etc.) si pertinent
          - Formule des phrases courtes et percutantes, comme un consultant qui a tout compris en 3 questions
          - Ne pose JAMAIS de question. Jamais de "qu'en penses-tu ?". Affirmations uniquement.
          - Max 120 mots au total
          - Pour le contexte : utilise UNIQUEMENT les données vérifiées ci-dessus ou ce qui a été explicitement dit dans la conversation. N'invente JAMAIS un effectif, un nombre d'ETP, un nombre de personnes ou un secteur non confirmé — si inconnu, décris la structure (ex : "atelier artisanal") sans chiffrer.

          Format OBLIGATOIRE (avec emojis, en Markdown) :

          🏭 **Contexte :** [#{contexte_line ? contexte_line + " + " : ""}type de structure + situation — n'invente PAS l'effectif s'il est inconnu]

          🎯 **Enjeu :** [la tension ou le défi réel, formulé avec précision — pas une reformulation, une analyse]

          🔧 **Déjà en place :** [ce qui a été essayé, présenté comme un atout ou une base à structurer]

          ⚡ **Urgence :** [court / moyen terme + pourquoi — justifié par un indice de la conversation]

          Réponds uniquement avec le contenu Markdown. Aucune intro, aucune conclusion, aucune question.
        PROMPT
      }
    ]

    render json: { summary: call_llm(messages) }
  end

  def create
    name    = params[:contact_name]
    email   = params[:contact_email]
    themes  = Array(params[:contact_themes])
    summary = params[:contact_summary]

    ContactMailer.new_contact(
      name:      name,
      email:     email,
      company:   params[:contact_company],
      phone:     params[:contact_phone],
      themes:    themes,
      summary:   summary,
      history:   params[:contact_history],
      precision: params[:contact_precision],
      sector:    params[:contact_sector],
      size:      params[:contact_size]
    ).deliver_later

    ContactMailer.confirmation_to_client(
      name:    name,
      email:   email,
      themes:  themes,
      summary: summary
    ).deliver_later

    redirect_to root_path, notice: "Votre demande a bien été envoyée ! Je vous réponds sous 24h."
  end

  private

  REALISATIONS = [
    { id: "N°01",
      scale: "PME-site / filiale GE (General Mills)",
      type_orga: "usine industrielle automatisée",
      context: "Yoplait (marque General Mills, GE mondial) · site Vienne · agroalimentaire · 200 personnes · 3 unités de production",
      titre: "Fusion des silos Production / Maintenance / Process",
      resultat: "+8% TRS · 480 K€/an · −30% aléas",
      tags: %w[agro agroalimentaire TRS rendement performance silos management] },
    { id: "N°02",
      scale: "ETI (CENEXI, 400p, 3 sites)",
      type_orga: "usine industrielle process continu",
      context: "CENEXI (CMO pharma indépendant, 400 personnes, 3 sites) · site Fontenay-sous-Bois · lignes de remplissage aseptiques automatisées",
      titre: "Plan de réduction des rebuts sur 18 mois",
      resultat: "450 K€/an économisés",
      tags: %w[pharma pharmaceutique rebuts qualité pertes SAP] },
    { id: "N°03",
      scale: "PME-site / filiale GE (Campbell Soup Co.)",
      type_orga: "usine industrielle automatisée",
      context: "LIEBIG (marque Campbell Soup Company, GE mondial) · site Le Pontet · agroalimentaire · lignes de production automatisées",
      titre: "Digitalisation du pilotage de la performance (TRS)",
      resultat: "240 K€/an · −50% arrêts non identifiés",
      tags: %w[agro agroalimentaire digital TRS OEE arrêts indicateurs tableau-de-bord] },
    { id: "N°04",
      scale: "PME-site / filiale GE (Campbell Soup Co.)",
      type_orga: "usine industrielle automatisée",
      context: "LIEBIG (marque Campbell Soup Company, GE mondial) · site Le Pontet · agroalimentaire · supply chain & production",
      titre: "Standardisation du packaging barquette",
      resultat: "400 K€ de gains · supply chain + production",
      tags: %w[agro agroalimentaire standardisation packaging flux supply-chain] },
    { id: "N°05",
      scale: "PME-site / filiale GE (Campbell Soup Co.)",
      type_orga: "usine industrielle automatisée",
      context: "LIEBIG (marque Campbell Soup Company, GE mondial) · site Le Pontet · 100 personnes · lignes automatisées",
      titre: "Organisation en Unités Autonomes de Production (UAP)",
      resultat: "TRS 57% → 67% · durées intervention ÷2",
      semantic_scope: "Pour : restructuration organisationnelle production/maintenance, création d'unités autonomes, amélioration TRS. NE PAS utiliser pour de l'animation d'équipe, de la motivation ou des rituels de management — utiliser N°16 pour ces sujets.",
      tags: %w[agro organisation UAP autonomie maintenance production TRS productivité capacité restructuration-orga] },
    { id: "N°06",
      scale: "ETI (CENEXI, 400p, 3 sites)",
      type_orga: "usine industrielle process continu",
      context: "CENEXI (CMO pharma, ETI 400p) · site Fontenay-sous-Bois · 170 personnes · production continue",
      titre: "Réduction de l'absentéisme de courte durée",
      resultat: "−10% absentéisme · +2 M ampoules/mois",
      semantic_scope: "UNIQUEMENT : arrêts maladie répétés, absentéisme, présence au travail, éviter les intérimaires mal formés. NE PAS utiliser pour : gain de productivité, capacité, isopérimètre, départs en retraite, flux, organisation des postes.",
      tags: %w[pharma absentéisme arrêts-maladie présence engagement management intérimaires] },
    { id: "N°07",
      scale: "PME-site / filiale GE (Campbell Soup Co.)",
      type_orga: "usine industrielle automatisée",
      context: "LIEBIG (marque Campbell Soup Company) · site Le Pontet · budget CAPEX 4 M€/an · industrie agroalimentaire",
      titre: "Plan Directeur CAPEX à 3 ans — 10 M€",
      resultat: "10 M€ planifiés · validé Direction Monde",
      tags: %w[agro CAPEX investissement stratégie direction] },
    { id: "N°08",
      scale: "PME-site / filiale GE (Campbell Soup Co.)",
      type_orga: "usine industrielle automatisée",
      context: "LIEBIG (marque Campbell Soup Company) · site Le Pontet · travaux neufs · industrie agroalimentaire",
      titre: "Mise aux normes HSE — LOTO, STEP, Bruit, Sprinklage",
      resultat: "930 K€ investis · conformité DREAL",
      tags: %w[HSE sécurité conformité réglementation travaux] },
    { id: "N°09",
      scale: "ETI (CENEXI, 400p, 3 sites)",
      type_orga: "usine industrielle process continu",
      context: "CENEXI (CMO pharma, ETI 400p) · site Fontenay-sous-Bois · 2 lignes de remplissage aseptiques automatisées",
      titre: "Organisation 7 jours/7 sur lignes aseptiques",
      resultat: "+500 000 ampoules/semaine",
      tags: %w[pharma capacité production organisation 7j7 weekend] },
    { id: "N°10",
      scale: "ETI/GE (client automobile)",
      type_orga: "industrie manufacturière",
      context: "Mission EFESO Consulting · sous-traitant automobile · intervention COMEX d'une structure ETI/GE",
      titre: "Plan de progrès avec un COMEX non aligné",
      resultat: "Mission signée · 4 mois terrain · COMEX converti",
      semantic_scope: "UNIQUEMENT pour : résistance au changement au niveau COMEX ou Direction, alignement stratégique entre dirigeants, plan de progrès avec des parties prenantes C-suite. NE PAS utiliser pour : coordination d'équipes terrain, management de proximité, animation des opérateurs — ce sont des défis fondamentalement différents.",
      tags: %w[auto automobile consulting COMEX changement résistance alignement-direction stratégie] },
    { id: "N°11",
      scale: "Micro-entreprise (Cyrille seul, 1-3 personnes)",
      type_orga: "atelier artisanal / travail 100% manuel",
      context: "Centaur Bike · Lyon · micro-entreprise fondée et gérée par Cyrille seul (1 à 3 personnes max) · atelier d'électrification et de reconditionnement de vélos électriques · travail exclusivement manuel · B2C et B2B · NE PAS présenter comme un atelier de 20 personnes",
      titre: "Création, pilotage et organisation d'un atelier artisanal de reconditionnement de vélos électriques",
      resultat: "250 K€ CA/an · Marge 39% · organisation complète de l'atelier de A à Z · 2ème prix pitch",
      semantic_scope: "Pertinent pour : défis de création, développement, croissance d'une TPE, recrutement des premiers collaborateurs, structuration d'une petite organisation, équilibre CA/recrutement. Cyrille a vécu le dilemme croissance vs recrutement en tant que dirigeant.",
      tags: %w[startup entrepreneuriat micro-entreprise TPE création pilotage croissance recrutement développement-commercial organisation atelier artisanal vélo reconditionnement] },
    { id: "N°12",
      scale: "PME petite (Enjoué, association, 20-50 personnes)",
      type_orga: "atelier artisanal / travail 100% manuel / 20-50 personnes",
      context: "Projet RE-PLAY · Enjoué · Lyon · association loi 1901 · atelier de reconditionnement artisanal de jouets · 20-50 personnes · travail exclusivement manuel · mission de mécénat de compétences (en cours)",
      titre: "Digitalisation des processus d'un atelier de reconditionnement manuel — UX inclusive zero-text, Poka-Yoke numérique",
      resultat: "Application Rails déployée en production · 6 points de contrôle qualité numérisés · traçabilité AGEC · opérateurs guidés sans texte",
      semantic_scope: "UNIQUEMENT pour : ateliers artisanaux manuels, structures d'insertion ou ESS, reconditionnement, digitalisation d'un processus manuel simple. NE PAS utiliser pour une PME industrielle classique (agroalimentaire, pharma, mécanique…) sous prétexte qu'elle a 20 personnes — le contexte est fondamentalement différent.",
      tags: %w[tech digital application Rails atelier manuel reconditionnement inclusion qualité traçabilité ESS association poka-yoke zero-text] },
    { id: "N°13",
      scale: "PME petite (atelier artisanal, petite équipe)",
      type_orga: "atelier artisanal / travail 100% manuel",
      context: "Projet Démontés · Centaur Bike · Saint-Fons · atelier de reconditionnement manuel de pièces vélos · petite équipe artisanale",
      titre: "Industrialisation d'un atelier artisanal de reconditionnement : Lean 5S, standardisation des postes, SOP, formation",
      resultat: "16 rôles modélisés · postes 5S organisés · SOP rédigées · tutoriels vidéo · filière réemploi structurée",
      semantic_scope: "UNIQUEMENT pour : ateliers artisanaux manuels, structures sans process industriel formalisé, reconditionnement, économie circulaire. NE PAS utiliser pour une PME industrielle (agroalimentaire, pharma…) car le type de structure est différent malgré une taille similaire.",
      tags: %w[lean 5S VSM SOP atelier artisanal reconditionnement manuel organisation industrialisation éco-circulaire processus petite-équipe] },
    { id: "N°14",
      scale: "ETI (GHM, 500 personnes)",
      type_orga: "industrie lourde / fonderie",
      context: "GHM (ETI, 500 personnes) · fonderie · Sommevoire · site industriel lourd",
      titre: "Conduite autonome d'un chantier de génie civil",
      resultat: "300 K€ budget · délais tenus · 100 K€/an",
      tags: %w[métallurgie fonderie génie-civil CAPEX travaux-neufs] },
    { id: "N°15",
      scale: "GE-site / filiale GE (STMicroelectronics, GE mondial)",
      type_orga: "industrie de haute technologie / salle blanche",
      context: "STMicroelectronics (GE mondial, semi-conducteurs) · site Crolles · 5 000 personnes sur site · salle blanche · production de semi-conducteurs",
      titre: "Management d'une équipe maintenance postée en salle blanche — TPM",
      resultat: "120 K€/an sur durée de vie équipements · 6 opérateurs managés · processus TPM structurés",
      tags: %w[semi-conducteurs maintenance TPM salle-blanche équipe-postée industrie-haute-tech GE] },
    { id: "N°16",
      scale: "PME-site / filiale GE (Campbell Soup Co.)",
      type_orga: "usine industrielle automatisée",
      context: "LIEBIG (marque Campbell Soup Company, GE mondial) · site Le Pontet · agroalimentaire · 100 personnes",
      titre: "Refonte du management de proximité — formation et alignement des chefs d'équipe",
      resultat: "Managers alignés · ambiance assainie · 0 tension syndicale · montée en compétences interne",
      tags: %w[agro management formation chefs-équipe alignement-terrain coordination-équipes animation-équipe DDS rituels-management management-visuel pilotage-terrain IRP développement-managers coaching management-de-proximité] },
    { id: "N°17",
      scale: "ETI/GE (SOGEFI, équipementier automobile)",
      type_orga: "industrie manufacturière / forge et traitement de surface",
      context: "SOGEFI (équipementier automobile, fabricant de barres de suspension) · mission EFESO Consulting · industrie automobile",
      titre: "Chantier WCM sur grenailleuse — groupe de travail pluridisciplinaire",
      resultat: "43 K€ économisés sur 3 mois · CAPEX 4 K€ · remise au standard · équipement fiabilisé",
      tags: %w[auto automobile WCM chantier amélioration-continue pluridisciplinaire fiabilité équipement maintenance TPM forge traitement-surface] },
    { id: "N°18",
      scale: "PME-site / filiale GE (Campbell Soup Co.)",
      type_orga: "usine industrielle automatisée",
      context: "LIEBIG (marque Campbell Soup Company, GE mondial) · site Le Pontet · agroalimentaire · 100 personnes",
      titre: "Réduction de la consommation MO cariste — méthode ECRS",
      resultat: "−3 ETP intérimaires · dimensionnement accepté sans conflit social · ECRS appliqué",
      tags: %w[agro ECRS MO optimisation-effectifs logistique-interne manutention productivité lean intérimaires] },
    { id: "N°19",
      scale: "ETI (CENEXI, 400p, 3 sites)",
      type_orga: "usine industrielle process continu",
      context: "CENEXI (CMO pharma, ETI 400p) · site Fontenay-sous-Bois · 170 personnes · lignes de remplissage aseptiques",
      titre: "Mise en place de nouveaux horaires 3×8 — négociation IRP et volontariat",
      resultat: "−10 ETP intérimaires · volume maintenu · accord IRP signé · démarrage sur volontariat",
      tags: %w[pharma horaires organisation 3x8 IRP négociation-sociale intérimaires changement volontariat] },
    { id: "N°20",
      scale: "ETI (CENEXI, 400p, 3 sites)",
      type_orga: "usine industrielle process continu",
      context: "CENEXI (CMO pharma, ETI 400p) · site Fontenay-sous-Bois · 170 personnes",
      titre: "Mise en place de la classification Leem et minima de salaire — fidélisation des opérateurs qualifiés",
      resultat: "Classification définie · minima salaires validés Direction · fidélisation renforcée en ZAC",
      tags: %w[pharma RH classification salaire fidélisation compétences convention-collective social emploi recrutement] },
    { id: "N°21",
      scale: "GE-site / filiale GE (STMicroelectronics, GE mondial)",
      type_orga: "industrie de haute technologie / salle blanche",
      context: "STMicroelectronics (GE mondial, semi-conducteurs) · site Crolles · 5 000 personnes · équipe postée 2×8 · salle blanche",
      titre: "Création d'un outil de passage de consignes en équipe postée",
      resultat: "Communication inter-équipes établie · problèmes récurrents tracés · bottleneck réduit",
      tags: %w[semi-conducteurs communication outil-digital passage-de-consignes équipe-postée traçabilité information partage] }
  ].freeze

  def build_system_prompt(themes, sector = nil, size = nil)
    themes_str = themes.any? ? themes.join(", ") : "non précisés"
    realisations_str = REALISATIONS.map do |r|
      lines = [
        "#{r[:id]} [scale:#{r[:scale]}] [type:#{r[:type_orga]}] [tags:#{r[:tags].join(', ')}]",
        "  Contexte : #{r[:context]}",
        "  Réalisation : #{r[:titre]}",
        "  Résultat : #{r[:resultat]}"
      ]
      lines << "  ⚠ Périmètre sémantique : #{r[:semantic_scope]}" if r[:semantic_scope]
      lines.join("\n")
    end.join("\n\n")

    visitor_context_lines = []
    visitor_context_lines << "Secteur : #{sector}" if sector.present?
    visitor_context_lines << "Taille : #{size}"    if size.present?

    visitor_section = if visitor_context_lines.any?
      <<~CTX
        CONTEXTE VISITEUR (renseigné par le visiteur dans le formulaire) :
        #{visitor_context_lines.join("\n")}
        → Ces informations sont CERTAINES — ne pose AUCUNE question sur le secteur ou la taille.
        → Utilise-les pour personnaliser l'accueil et matcher les réalisations dès Q1.

      CTX
    else
      ""
    end

    <<~PROMPT
      Tu es l'assistant de contact de Cyrille PIERRE, consultant indépendant spécialisé en management de transition, excellence opérationnelle et tech/IA.
      Thèmes sélectionnés par le visiteur : #{themes_str}

      #{visitor_section}POSITIONNEMENT ACTUEL DE CYRILLE (depuis mars 2026) :
      Cyrille est manager de transition et consultant indépendant. Il intervient en mission courte ou longue dans des organisations pour piloter une transformation, redresser la performance ou construire des outils digitaux sur mesure. Il connaît le métier de manager de transition de l'intérieur — il le pratique.

      → Pour les cabinets de management de transition, les sociétés de conseil ou les structures qui pilotent des managers en mission : Cyrille est un interlocuteur naturel, il parle le même langage et comprend les enjeux de suivi, de performance et de relation client.
      → Pour les entreprises industrielles : il arrive avec 20 ans de terrain et des résultats mesurables.
      → Pour les projets digitaux ou IA : il conçoit et développe lui-même les outils (Ruby on Rails, LLM, API).

      PROFIL DE CYRILLE — triple expertise :

      1. GRANDES INDUSTRIES (sites PME à ETI/GE, production automatisée) :
         - Yoplait/General Mills (GE mondial) — site 200p, directeur production 3 unités agro
         - LIEBIG/Campbell Soup (GE mondial) — site 100p, responsable unité de production agro
         - CENEXI (ETI, 400p, 3 sites) — 170p sur site, resp. fabrication liquides injectables pharma
         - STMicroelectronics (GE mondial, 5 000p sur site Crolles) — chef équipe maintenance salle blanche, semi-conducteurs
         - GHM fonderie (ETI, 500p) — ingénieur travaux neufs
         - EFESO Consulting — missions conseil auprès de COMEX automobile
         - SOGEFI (équipementier automobile) — chantier WCM terrain via EFESO

      2. PETITES STRUCTURES MANUELLES (TPE / artisanal, 20 à 50 personnes, travail 100% manuel) :
         - Centaur Bike : atelier d'électrification et de reconditionnement de vélos électriques, B2C+B2B, 250 K€ CA
         - Projet Démontés : industrialisation d'un atelier artisanal de reconditionnement de pièces vélos, Lean 5S, SOP
         - Projet RE-PLAY / Enjoué : digitalisation des processus d'un atelier de reconditionnement de jouets (20-50 personnes), UX zero-text, Poka-Yoke numérique

      3. DIGITAL & OUTILS MÉTIER (tout secteur, tout type de structure) :
         - Application Rails de suivi qualité et en-cours déployée en production (RE-PLAY)
         - Digitalisation du pilotage de la performance TRS (tableau de bord tactile, LIEBIG)
         - Outil de passage de consignes en équipe postée (STMicro)
         - Ce site web + assistant IA de contact (conçu et développé par Cyrille lui-même)

      → Cyrille est à l'aise dans les trois registres. La dimension digitale est transversale à tous les secteurs.

      RÉALISATIONS DE CYRILLE :
      #{realisations_str}

      Chaque réalisation indique :
      - scale : TPE (<20p) / PME (20-50p) / ETI (50-500p) / GE (>500p)
      - type_orga : le type de structure (usine industrielle automatisée / atelier artisanal manuel / startup / etc.)

      TON RÔLE : collecter les informations essentielles en exactement 3 questions ET, si pertinent, rassurer le visiteur en citant une expérience de Cyrille comparable à son contexte.

      PROTOCOLE STRICT :

      [MESSAGE __START__]
      → Accueil chaleureux en 1-2 phrases.
      #{visitor_context_lines.any? ? "  Le secteur#{size.present? ? ' et la taille' : ''} du visiteur #{size.present? ? 'sont connus' : 'est connu'} — mentionne-le brièvement pour personnaliser l'accueil. Ne pose PAS de question sur le secteur ou la taille." : ""}
      → QUESTION 1 : "Quel est votre principal défi ou objectif ?"

      [APRÈS RÉPONSE 1 — défi connu]
      → Si la réponse est vague ou incomplète : demande une précision, puis ajoute ##CLARIFY## sur la dernière ligne.
      → Si la réponse est claire : ÉVALUE si une réalisation pertinente peut être citée, en suivant cette logique :
        1. Si le défi est DIGITAL / OUTIL / SUIVI / TABLEAU DE BORD / INDICATEURS → citer en priorité les réalisations tech : N°03 (digitalisation TRS), N°12 (application RE-PLAY), N°21 (outil de consignes). Mentionner que Cyrille développe lui-même les outils.
        2. Si le visiteur est un CABINET DE CONSEIL, une SOCIÉTÉ DE MANAGEMENT DE TRANSITION ou un INTERMÉDIAIRE → souligner que Cyrille est lui-même manager de transition, il connaît le métier de l'intérieur.
        3. Si le visiteur est une TPE / petite structure avec un défi de CROISSANCE, RECRUTEMENT, STRUCTURATION ou DÉVELOPPEMENT COMMERCIAL → citer N°11 (Centaur Bike) : Cyrille a lui-même vécu le dilemme croissance/recrutement en tant que dirigeant d'une micro-entreprise.
        4. Pour les autres défis : cherche d'abord par TYPE DE DÉFI (productivité, absentéisme, management, RH, WCM, CAPEX…)
        4. Croise avec le contexte entreprise (secteur + taille) pour valider la pertinence
        5. Si le secteur est différent (BTP, logistique, finance, santé hors pharma, services…) → cite par TYPE DE DÉFI, précise brièvement "dans un contexte industriel" — NE PAS forcer une analogie sectorielle
        6. Si atelier artisanal / reconditionnement / ESS / structure sans process industriel formalisé → cite N°12 ou N°13. NE PAS les citer pour une PME industrielle classique (agro, pharma, mécanique…) même si elle a 20 personnes — vérifier le type de structure, pas seulement la taille
        7. Si aucune réalisation ne correspond vraiment → acquiescement simple sans forcer
      → QUESTION 2 : "Avez-vous déjà essayé des approches pour y remédier ?"

      [APRÈS RÉPONSE 2 — approches connues]
      → Si la réponse est vague ou manquante : demande une précision, puis ajoute ##CLARIFY## sur la dernière ligne.
      → Si la réponse est suffisante : acquiescement simple.
      → QUESTION 3 : "Quel serait le signe concret qui vous ferait dire que la mission est réussie ?"

      [APRÈS RÉPONSE 3 — OBLIGATOIRE]
      → Si la réponse est vague ou manquante : demande une précision, puis ajoute ##CLARIFY## sur la dernière ligne.
      → Si la réponse est suffisante :
        1 à 2 phrases montrant que tu as compris (reformulation ou lien avec la situation).
        Nouvelle ligne : "Merci, j'ai tout ce qu'il me faut pour préparer votre résumé !"
        Ligne suivante : ##READY##
        Stop. Rien d'autre après ##READY##.

      [SIGNAL ##CLARIFY##]
      → Utilise ##CLARIFY## UNIQUEMENT si la réponse est réellement incomplète au point de ne pas pouvoir avancer (ex : secteur manquant si indispensable, réponse hors sujet).
      → NE PAS utiliser ##CLARIFY## si la réponse donne une direction claire même imprécise — "améliorer la productivité", "réduire les coûts", "mieux manager mes équipes" sont suffisants pour enchaîner.
      → Format : ta question de clarification courte, puis ##CLARIFY## seul sur la dernière ligne.
      → Après ##CLARIFY##, attends la réponse avant de poursuivre vers la question principale suivante.
      → Maximum 1 ##CLARIFY## par question principale.

      RÈGLES ABSOLUES :
      - Réponds toujours en français
      - Corrige silencieusement les artefacts de saisie vocale évidents (ex : "île manufacturing" → Lean Manufacturing, "capex" mal orthographié, termes phonétiquement déformés) — ne les relève pas, utilise simplement le bon terme dans ta réponse
      - Tes réponses sont courtes et percutantes (3 phrases max par réponse)
      - Sépare TOUJOURS ta réponse/acquiescement de la question suivante par une ligne vide (\\n\\n) — la question doit apparaître visuellement séparée, comme un nouveau paragraphe
      - Ne cite jamais les identifiants internes (N°XX, scale, type_orga, les tags)
      - Ne cite JAMAIS la même réalisation deux fois dans la même conversation
      - Tu NE poses JAMAIS une 4ème question
      - Tu NE proposes JAMAIS un appel ou un rendez-vous
      - INTERDIT de comparer une TPE/atelier artisanal à une usine industrielle de 100+ personnes automatisée : ce serait contre-productif et peu crédible
      - Pour un atelier artisanal ou une TPE, utilise l'expérience Démontés (N°13) ou RE-PLAY/Enjoué (N°12) qui concernent de vraies équipes de 20-50 personnes. Centaur Bike (N°11) = Cyrille seul, 1-3 personnes max — ne PAS l'utiliser comme référence d'équipe de 20 personnes
      - INTERDIT de confondre l'absentéisme (arrêts maladie, présence au travail) avec un défi de productivité (faire autant ou plus avec moins de personnes). Ce sont deux problèmes fondamentalement différents. La réalisation N°06 (absentéisme CENEXI) ne s'applique PAS à un défi de productivité, de capacité ou de départs en retraite
      - Ne jamais inventer ni extrapoler des chiffres (effectifs, CA, résultats) qui ne figurent pas explicitement dans les réalisations
      - SECTEUR INCONNU : si le visiteur est dans un secteur où Cyrille n'a pas opéré (BTP, logistique, finance, distribution, santé hors pharma, IT, services…), NE PAS forcer une analogie sectorielle. Citer une réalisation par type de défi similaire en précisant "dans un contexte industriel, mais le défi est comparable". C'est plus honnête et plus crédible qu'une comparaison forcée.
      - DÉFI SANS RÉFÉRENCE : si le défi est de nature purement commerciale (développement de marché, réponse aux appels d'offres, prospection, pricing…), Cyrille n'a pas de réalisation directe sur ce sujet. Dans ce cas : ne PAS forcer de comparaison. Acquiescement simple, passer à la question suivante.
    PROMPT
  end

  def call_llm(messages)
    uri = URI("https://models.inference.ai.azure.com/chat/completions")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 45

    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{ENV.fetch('GITHUB_KEY', '')}"
    req["Content-Type"]  = "application/json"
    req.body = { model: "gpt-4o-mini", messages: messages, max_tokens: 600, temperature: 0.7 }.to_json

    response = http.request(req)
    data = JSON.parse(response.body)

    content = data.dig("choices", 0, "message", "content")
    unless content
      Rails.logger.error "ContactsController LLM bad response (HTTP #{response.code}): #{response.body.truncate(500)}"
    end
    content || "Je rencontre une difficulté technique. Écrivez directement à cyrille.pierre@gmail.com"
  rescue => e
    Rails.logger.error "ContactsController LLM error: #{e.class} — #{e.message}"
    "Je rencontre une difficulté technique. Écrivez directement à cyrille.pierre@gmail.com"
  end
end
