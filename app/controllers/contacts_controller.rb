require "net/http"

class ContactsController < ApplicationController
  def new
  end

  def chat
    message = params[:message].to_s.strip
    history = params[:history] || []
    themes  = params[:themes]  || []
    initial = params[:initial].to_s == "true"

    messages = [{ role: "system", content: build_system_prompt(themes) }]
    history.each { |m| messages << { role: m["role"], content: m["content"] } }
    messages << { role: "user", content: initial ? "__START__" : message }

    reply = call_llm(messages)
    render json: { reply: reply, ready: reply.include?("##READY##") }
  end

  def summarize
    history = params[:history] || []
    themes  = params[:themes]  || []

    messages = [
      { role: "system", content: "Tu rédiges des résumés structurés de demandes clients. Réponds en français." },
      *history.map { |m| { role: m["role"], content: m["content"] } },
      {
        role: "user",
        content: <<~PROMPT
          Tu es un analyste expert. À partir de la conversation ci-dessus, rédige un résumé en Markdown pour Cyrille PIERRE, consultant.
          Thèmes sélectionnés : #{themes.join(", ")}.

          CONSIGNES :
          - Ne reformule PAS ce qui a été dit mot pour mot : SYNTHÉTISE et ANALYSE
          - Identifie les signaux forts (tension, croissance, blocage, ce qui a déjà été tenté)
          - Utilise un vocabulaire métier précis (Lean, 5S, flux, capacité, management visuel, etc.) si pertinent
          - Formule des phrases courtes et percutantes, comme un consultant qui a tout compris en 3 questions
          - Ne pose JAMAIS de question. Jamais de "qu'en penses-tu ?". Affirmations uniquement.
          - Max 120 mots au total

          Format OBLIGATOIRE (avec emojis, en Markdown) :

          🏭 **Contexte :** [secteur + taille + type réel de structure — ex : "Atelier de confection artisanal, 20 personnes, en phase de croissance"]

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
      precision: params[:contact_precision]
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
      tags: %w[agro organisation UAP autonomie maintenance production TRS productivité capacité isopérimètre] },
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
      tags: %w[auto automobile consulting COMEX changement résistance alignment] },
    { id: "N°11",
      scale: "Micro-entreprise (Cyrille seul, 1-3 personnes)",
      type_orga: "atelier artisanal / travail 100% manuel",
      context: "Centaur Bike · Lyon · micro-entreprise fondée et gérée par Cyrille seul (1 à 3 personnes max) · atelier d'électrification et de reconditionnement de vélos électriques · travail exclusivement manuel · B2C et B2B · NE PAS présenter comme un atelier de 20 personnes",
      titre: "Création, pilotage et organisation d'un atelier artisanal de reconditionnement de vélos électriques",
      resultat: "250 K€ CA/an · Marge 39% · organisation complète de l'atelier de A à Z · 2ème prix pitch",
      tags: %w[startup entrepreneuriat micro-entreprise atelier manuel reconditionnement vélo électrique organisation création pilotage] },
    { id: "N°12",
      scale: "PME petite (Enjoué, association, 20-50 personnes)",
      type_orga: "atelier artisanal / travail 100% manuel / 20-50 personnes",
      context: "Projet RE-PLAY · Enjoué · Lyon · association loi 1901 · atelier de reconditionnement artisanal de jouets · 20-50 personnes · travail exclusivement manuel · mission de mécénat de compétences (en cours)",
      titre: "Digitalisation des processus d'un atelier de reconditionnement manuel — UX inclusive zero-text, Poka-Yoke numérique",
      resultat: "Application Rails déployée en production · 6 points de contrôle qualité numérisés · traçabilité AGEC · opérateurs guidés sans texte",
      tags: %w[tech digital application Rails atelier manuel reconditionnement inclusion qualité traçabilité PME-petite processus poka-yoke] },
    { id: "N°13",
      scale: "PME petite (atelier artisanal, petite équipe)",
      type_orga: "atelier artisanal / travail 100% manuel",
      context: "Projet Démontés · Centaur Bike · Saint-Fons · atelier de reconditionnement manuel de pièces vélos · petite équipe artisanale",
      titre: "Industrialisation d'un atelier artisanal de reconditionnement : Lean 5S, standardisation des postes, SOP, formation",
      resultat: "16 rôles modélisés · postes 5S organisés · SOP rédigées · tutoriels vidéo · filière réemploi structurée",
      tags: %w[lean 5S VSM SOP atelier artisanal reconditionnement manuel organisation PME-petite industrialisation éco-circulaire processus] },
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
      tags: %w[semi-conducteurs maintenance TPM salle-blanche équipe-postée industrie-haute-tech GE] }
  ].freeze

  def build_system_prompt(themes)
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

    <<~PROMPT
      Tu es l'assistant de contact de Cyrille PIERRE, consultant indépendant (Excellence Opérationnelle, Leadership, Tech & IA).
      Thèmes sélectionnés par le visiteur : #{themes_str}

      PROFIL DE CYRILLE — double expertise (à utiliser pour contextualiser les réalisations) :
      Cyrille a exercé dans deux types de structures très différents :

      1. GRANDES INDUSTRIES (sites PME à ETI/GE, production automatisée) :
         - Yoplait/General Mills (GE mondial) — site 200p, directeur production 3 unités agro
         - LIEBIG/Campbell Soup (GE mondial) — site 100p, responsable unité de production agro
         - CENEXI (ETI, 400p, 3 sites) — 170p sur site, resp. fabrication liquides injectables pharma
         - STMicroelectronics (GE mondial, 5 000p sur site Crolles) — chef équipe maintenance salle blanche, semi-conducteurs
         - GHM fonderie (ETI, 500p) — ingénieur travaux neufs
         - EFESO Consulting — missions conseil auprès de COMEX automobile

      2. PETITES STRUCTURES MANUELLES (TPE / artisanal, 20 à 50 personnes, travail 100% manuel) :
         - Centaur Bike : atelier d'électrification et de reconditionnement de vélos électriques, travail entièrement manuel, B2C+B2B, 250 K€ CA
         - Projet Démontés : industrialisation d'un atelier artisanal de reconditionnement de pièces vélos, Lean 5S, SOP, standardisation des postes
         - Projet RE-PLAY / Enjoué : digitalisation des processus d'un atelier de reconditionnement de jouets (20-50 personnes), UX inclusive zero-text, Poka-Yoke numérique

      → Cyrille est à l'aise avec les deux types de structures. Pour les petites structures manuelles et les ateliers artisanaux, il a une expérience directe et concrète — ce n'est pas théorique.

      RÉALISATIONS DE CYRILLE :
      #{realisations_str}

      Chaque réalisation indique :
      - scale : TPE (<20p) / PME (20-50p) / ETI (50-500p) / GE (>500p)
      - type_orga : le type de structure (usine industrielle automatisée / atelier artisanal manuel / startup / etc.)

      TON RÔLE : collecter les informations essentielles en exactement 3 questions ET, si pertinent, rassurer le visiteur en citant une expérience de Cyrille comparable à son contexte.

      PROTOCOLE STRICT :

      [MESSAGE __START__]
      → Accueil chaleureux en 1 phrase, puis QUESTION 1 :
        "Dans quel secteur évoluez-vous, et quelle est la taille de votre structure (nombre de personnes, artisanal, PME, grande entreprise) ?"

      [APRÈS RÉPONSE 1 — secteur/taille connus]
      → ÉVALUE D'ABORD : y a-t-il une réalisation dont le scale ET le type_orga sont vraiment proches du contexte décrit ?
        • Si le visiteur est une petite structure manuelle ou un atelier artisanal (TPE, 20-50p) → les réalisations N°11, N°12, N°13 sont directement comparables. Cite l'une d'elles : "Cyrille a justement organisé [contexte réal.] avec [résultat] — un contexte très proche du vôtre."
        • Si le visiteur est une ETI ou GE industrielle → cite une réalisation N°01 à N°10 pertinente.
        • Si vraiment aucune réalisation ne correspond (secteur très éloigné) → ne force rien, enchaîne directement sur la Q2.
      → QUESTION 2 : "Quel est votre principal défi ou objectif ?"

      [APRÈS RÉPONSE 2 — défi connu]
      → ÉVALUE à nouveau : y a-t-il une réalisation pertinente par rapport au défi exprimé (problématique comparable, peu importe le secteur) ?
        • Si OUI → cite-la : "Ce type de défi, Cyrille l'a rencontré chez [contexte] : [résultat bref]."
        • Si NON → acquiescement simple, sans forcer de référence.
      → QUESTION 3 : "Avez-vous déjà essayé des approches pour y remédier ?"

      [APRÈS RÉPONSE 3 — OBLIGATOIRE]
      → D'abord : 1 à 2 phrases qui montrent que tu as compris la réponse (reformulation ou lien avec la situation). Rassure le visiteur sur le fait que son contexte est bien saisi.
      → Ensuite sur une nouvelle ligne : "Merci, j'ai tout ce qu'il me faut pour préparer votre résumé !"
      → Puis sur la ligne suivante : ##READY##
      → Stop. Rien d'autre après ##READY##.

      RÈGLES ABSOLUES :
      - Réponds toujours en français
      - Tes réponses sont courtes et percutantes (3 phrases max par réponse)
      - Ne cite jamais les identifiants internes (N°XX, scale, type_orga, les tags)
      - Tu NE poses JAMAIS une 4ème question
      - Tu NE proposes JAMAIS un appel ou un rendez-vous
      - INTERDIT de comparer une TPE/atelier artisanal à une usine industrielle de 100+ personnes automatisée : ce serait contre-productif et peu crédible
      - Pour un atelier artisanal ou une TPE, utilise l'expérience Démontés (N°13) ou RE-PLAY/Enjoué (N°12) qui concernent de vraies équipes de 20-50 personnes. Centaur Bike (N°11) = Cyrille seul, 1-3 personnes max — ne PAS l'utiliser comme référence d'équipe de 20 personnes
      - INTERDIT de confondre l'absentéisme (arrêts maladie, présence au travail) avec un défi de productivité (faire autant ou plus avec moins de personnes). Ce sont deux problèmes fondamentalement différents. La réalisation N°06 (absentéisme CENEXI) ne s'applique PAS à un défi de productivité, de capacité ou de départs en retraite
      - Ne jamais inventer ni extrapoler des chiffres (effectifs, CA, résultats) qui ne figurent pas explicitement dans les réalisations
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
