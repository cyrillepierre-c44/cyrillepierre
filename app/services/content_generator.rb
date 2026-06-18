# Builds the prompt for a Generation (based on its kind and sources) and calls the LLM.
# rubocop:disable Metrics/ClassLength
class ContentGenerator
  MAMMOUTH_API_BASE = "https://api.mammouth.ai/v1"
  # Proofreading always runs on GitHub Models (free tier) regardless of the model chosen
  # for the draft, so the extra LLM call doesn't add cost.
  PROOFREADING_MODEL = "gpt-4o-mini"

  KIND_PROMPT_METHODS = {
    linkedin_post: :linkedin_post_prompt,
    cover_letter: :cover_letter_prompt,
    commercial_proposal: :commercial_proposal_prompt,
    site_actu: :site_actu_prompt
  }.freeze

  ORIENTATION_GUIDANCE = {
    "consultant" => <<~TXT,
      Orientation CONSULTANT : Cyrille se positionne comme prestataire externe disponible pour des missions
      ponctuelles (audit, accompagnement, chantier défini). Le post doit donner envie de le solliciter pour
      une mission précise — invite à échanger sur une problématique similaire, sans pousser de lien ni de
      template à télécharger. Le lecteur cible est un dirigeant, un DAF/CFO ou un responsable opérationnel
      qui pourrait avoir un besoin comparable à traiter.
    TXT
    "transition_management" => <<~TXT,
      Orientation MANAGER DE TRANSITION : Cyrille se positionne comme un manager de transition disponible
      pour reprendre une responsabilité opérationnelle en urgence ou sur une durée définie (départ soudain,
      crise, fusion, redressement). Ton direct et pragmatique, axé sur la capacité à être opérationnel
      immédiatement sans phase d'observation. Le lecteur cible est un actionnaire, un fonds d'investissement,
      un COMEX ou un cabinet de management de transition.
    TXT
    "cdi_search" => <<~TXT
      Orientation RECHERCHE DE POSTE EN CDI : Cyrille montre qu'il s'inscrit dans la durée — capacité à
      construire, faire grandir une équipe, porter un sujet sur plusieurs années. Pas de ton "prestataire
      disponible immédiatement" : on est sur de l'engagement long terme. Le lecteur cible est un recruteur,
      un DG ou un futur N+1, pas un investisseur.
    TXT
  }.freeze

  PROOFREADING_INSTRUCTIONS = <<~PROMPT
    Tu es un correcteur orthographique et grammatical, rien de plus.
    Corrige UNIQUEMENT les fautes d'orthographe, de grammaire, de conjugaison et les mots mal formés
    (ex. "una réduction" → "une réduction") dans le texte fourni.
    Ne change RIEN d'autre : pas de reformulation, pas de changement de style ou de ton, pas d'ajout ni de
    suppression de contenu, pas de changement de longueur. Conserve exactement la même structure, y compris
    les lignes de marqueurs au format ###NOM_DE_MARQUEUR### si le texte en contient — ne les modifie jamais.
    Réponds uniquement avec le texte corrigé, rien d'autre avant ou après.
  PROMPT

  def self.call(generation)
    new(generation).call
  end

  def initialize(generation)
    @generation = generation
  end

  def call
    draft = new_chat.with_instructions(system_prompt).ask(user_prompt).content.to_s

    generation.update!(output: proofread(draft), status: :generated)
    generation
  rescue StandardError => e
    Rails.logger.error "ContentGenerator error: #{e.class} — #{e.message}"
    generation.update!(output: "Erreur lors de la génération : #{e.message}", status: :draft)
    generation
  end

  private

  attr_reader :generation

  def new_chat
    model = generation.llm_model
    case generation.llm_provider
    when :mammouth
      mammouth_context.chat(model: model, provider: :openai, assume_model_exists: true)
    else
      RubyLLM.chat(model: model)
    end
  end

  def mammouth_context
    @mammouth_context ||= RubyLLM.context do |c|
      c.openai_api_key = ENV.fetch("MAMMOUTH_API_KEY", nil)
      c.openai_api_base = MAMMOUTH_API_BASE
    end
  end

  def proofread(text)
    return text if text.blank?

    RubyLLM.chat(model: PROOFREADING_MODEL).with_instructions(PROOFREADING_INSTRUCTIONS).ask(text).content.to_s
  rescue StandardError => e
    Rails.logger.error "ContentGenerator proofread error: #{e.class} — #{e.message}"
    text
  end

  def system_prompt
    kind_prompt = send(KIND_PROMPT_METHODS.fetch(generation.kind.to_sym))
    "#{critical_writing_guidelines}\n\n#{kind_prompt}"
  end

  def critical_writing_guidelines
    <<~PROMPT
      RÈGLES D'ÉCRITURE (s'appliquent à tout ce que tu rédiges, quel que soit le type de contenu) :
      Tu es un assistant de rédaction critique. L'objectif n'est pas un texte parfait et lisse, mais un texte qui
      semble écrit par une personne compétente et impliquée, capable d'assumer chaque phrase.

      - Style humain : phrases de longueur variée, fluide, professionnel mais pas trop lisse
      - Évite les formulations génériques typiques de l'IA, notamment : "dans un monde en constante évolution",
        "il est essentiel de", "cela permet de", "en conclusion", "il convient de souligner", "de manière
        générale", "optimiser les processus", "tirer parti de", "fort de mon expérience", "je suis convaincu
        que", "véritable levier", "au cœur des enjeux"
      - Écris comme quelqu'un qui connaît réellement son sujet : intègre, quand c'est pertinent, du contexte
        réel, des contraintes, des nuances, des difficultés rencontrées, des choix effectués et leur justification
      - Ne fabrique jamais de vécu personnel. Si une information personnelle manque pour rendre une phrase
        crédible, écris littéralement "[À compléter avec un exemple personnel]" plutôt que d'inventer
      - Préserve le fond : ne modifie pas les faits, chiffres, dates, expériences ou compétences fournis dans les
        sources, et ne rends jamais le texte plus impressionnant que ce qui est réellement justifiable par les
        sources
      - Ton sobre, direct et crédible plutôt que promotionnel — le texte doit convaincre par sa précision, pas
        par des slogans
      - Structure sans excès : paragraphes courts et logiques, pas de plan mécanique ni de transitions artificielles
      - N'achève JAMAIS un texte par une liste à puces ou une énumération numérotée de compétences/avantages
        ("1. La maîtrise technique 2. Le pilotage industriel…") — même pour résumer plusieurs points forts,
        reste en prose, intégrée dans des phrases qui s'enchaînent naturellement
      - Préfère un vocabulaire concret et métier à des termes managériaux génériques quand le contexte le permet
        (ex. "changement de série", "ligne de remplissage", "ordonnancement", "non-conformité" plutôt que
        "optimisation des processus", "pilotage de la performance")
      - Varie réellement la longueur et la construction des phrases d'un paragraphe à l'autre — évite que
        plusieurs phrases consécutives suivent le même schéma sujet-verbe-complément
      - Si une affirmation factuelle nécessiterait une source, une date ou un chiffre que tu n'as pas, signale-le
        explicitement avec "[À vérifier avant envoi]" plutôt que de la présenter comme certaine
    PROMPT
  end

  def user_prompt
    parts = []
    parts << "Texte collé par l'utilisateur :\n#{generation.input_text}" if generation.input_text.present?
    parts << "Contenu extrait de l'URL fournie :\n#{scraped_url_text}" if generation.input_url.present?
    parts << "Contenu extrait du fichier joint :\n#{extracted_file_text}" if generation.source_file.attached?
    if generation.extra_instructions.present?
      parts << "Instructions complémentaires :\n#{generation.extra_instructions}"
    end
    parts.join("\n\n").presence ||
      "Aucune source fournie — génère un contenu générique à partir du profil de Cyrille ci-dessus."
  end

  def scraped_url_text
    UrlScraper.call(generation.input_url)
  rescue UrlScraper::UnsafeUrlError => e
    "(impossible de récupérer cette URL : #{e.message})"
  end

  def extracted_file_text
    FileTextExtractor.call(generation.source_file)
  end

  def realisations_str
    RealisationCatalog::ITEMS.map do |r|
      "#{r[:id]} #{r[:titre]} — #{r[:context]} — #{r[:resultat]}"
    end.join("\n")
  end

  def cv_context
    "CV COMPLET DE CYRILLE (source la plus détaillée et la plus à jour — intitulés de poste exacts, dates, " \
    "clients, missions de conseil — à privilégier sur le catalogue ci-dessus en cas de détail manquant ou " \
    "de différence) :\n#{CvText.call}"
  rescue StandardError => e
    Rails.logger.error "ContentGenerator cv_context error: #{e.class} — #{e.message}"
    ""
  end

  def linkedin_post_prompt
    <<~PROMPT
      Tu rédiges des posts LinkedIn pour Cyrille PIERRE, consultant indépendant en management de transition,
      excellence opérationnelle et tech/IA. Ton style : direct, concret, pas de jargon creux, pas d'emoji excessif.

      CONTEXTE STRATÉGIQUE :
      Cyrille publie 2 à 3 posts par semaine, avec deux objectifs : démontrer son expertise via des thèmes liés à
      ses compétences et réalisations, et générer des opportunités selon l'orientation choisie ci-dessous.
      Il suit actuellement la formation ICCF (HEC) — analyse financière et valorisation d'entreprises — pour
      apprendre à parler le langage des décideurs financiers (CFO, actionnaires, investisseurs, COMEX). Ce sont
      eux qui valident les budgets de digitalisation, de chantiers Lean, de réorganisation ou de mission de
      management de transition. L'angle à privilégier autant que possible : relier l'impact opérationnel d'une
      réalisation à ce qui compte pour ces décideurs (coûts évités, capacité libérée, risque réduit, rentabilité
      d'un investissement) — sans pour autant transformer chaque post en cours de finance.

      #{ORIENTATION_GUIDANCE.fetch(generation.orientation, ORIENTATION_GUIDANCE['consultant'])}

      RÉALISATIONS DE CYRILLE (à citer si pertinent, sans les identifiants internes type N°XX) :
      #{realisations_str}

      #{cv_context}

      #{recent_posts_context}

      CANEVAS À SUIVRE (adapte la longueur de chaque partie au sujet, mais respecte cet enchaînement) :
      1. Hook — 1 à 2 lignes qui donnent envie de lire la suite (chiffre surprenant, affirmation tranchée, question
         directe). Pas de mise en contexte avant le hook.
      2. Contexte — la situation de départ, le problème ou la contrainte rencontrée, en 2-4 lignes concrètes.
      3. Résultat — ce qui a été fait et obtenu, avec les chiffres/faits réels fournis dans les sources.
      4. Ouverture — la question ouverte ou l'invitation à réagir qui clôt le post (voir consignes ci-dessous).

      MISE EN FORME :
      - Tu peux mettre en gras, avec la syntaxe markdown **comme ceci**, l'accroche ou 2-3 mots-clés maximum dans
        tout le post (chiffre clé, nom de l'enjeu) — jamais une phrase entière, et jamais plus de 3 passages en gras
      - 1 à 3 emojis ciblés maximum dans tout le post, jamais en décoration : un emoji n'est légitime qu'attaché à
        un chiffre, un résultat ou une étape clé (ex. "📊 +8% de TRS", "🎯 l'objectif"), jamais en début de chaque
        ligne ni pour faire joli

      CONSIGNES :
      - 150 à 250 mots
      - Phrases courtes, retours à la ligne fréquents (format LinkedIn, pas de gros pavés)
      - Choisis une réalisation différente de celles déjà utilisées dans les posts récents listés ci-dessus,
        sauf si aucune autre ne convient au sujet
      - Quand c'est pertinent, traduis le résultat opérationnel en langage compréhensible par un décideur financier
        (ex. "moins d'arrêts machine non planifiés" → "un risque opérationnel mieux maîtrisé"), MAIS uniquement à
        partir des chiffres et faits réellement fournis dans les réalisations ou les sources — jamais de ratio,
        pourcentage ou indicateur financier (EBITDA, ROI, WACC, multiple de valorisation…) qui n'est pas
        explicitement donné dans les sources
      - N'invente et ne cite jamais de résultat financier précis (chiffre, %, point) pour une entreprise nommée
        si ce chiffre ne figure pas dans les réalisations fournies — en cas de doute, reste qualitatif
        ("a contribué à réduire les coûts", sans inventer le montant) plutôt que d'inventer un chiffre
      - Termine par une question ouverte ou une invitation à réagir, sans "lien en commentaire" artificiel et
        sans formule de growth-hacking creuse (pas de "MP-moi le mot clé X, je t'envoie mon template")
      - Pas de hashtags excessifs (3 maximum, à la fin)
      - Ne jamais inventer de chiffres ou de faits non fournis dans les sources
      - Réponds uniquement avec le texte du post, sans titre ni commentaire autour
    PROMPT
  end

  def recent_posts_context
    posts = Generation.where(kind: :linkedin_post, status: %i[generated published])
                      .where.not(id: generation.id)
                      .order(created_at: :desc)
                      .limit(5)
                      .pluck(:output)
                      .compact_blank

    return "Aucun post LinkedIn récent à éviter de répéter." if posts.empty?

    intro = "POSTS LINKEDIN RÉCENTS DE CYRILLE (ne réutilise PAS la même réalisation ni la même accroche) :"
    body = posts.each_with_index.map { |text, i| "--- Post récent #{i + 1} ---\n#{text.truncate(500)}" }.join("\n\n")
    "#{intro}\n#{body}"
  end

  # rubocop:disable Metrics/MethodLength
  def structured_output_instructions
    markers = Generation::SECTION_MARKERS
    <<~PROMPT
      FORMAT DE RÉPONSE OBLIGATOIRE :
      Ce document sera relu et adapté à la main avant envoi — structure ta réponse en 4 sections, chacune
      précédée par son marqueur exact, seul sur sa ligne, dans cet ordre :

      #{markers[:final]}
      Le texte final, prêt à être personnalisé puis envoyé.

      #{markers[:personalize]}
      Une liste à puces des passages que Cyrille doit relire ou adapter avec ses propres mots avant envoi
      (ex. : détails spécifiques à l'entreprise visée, ton à ajuster).

      #{markers[:verify]}
      Une liste à puces des affirmations, chiffres ou dates qui nécessitent une vérification, ou vide
      ("Aucun élément à vérifier.") si tout provient des sources fournies.

      #{markers[:short]}
      Une version plus courte et directe du texte final (la moitié de la longueur environ).

      N'écris rien avant le premier marqueur ni après la dernière section.
    PROMPT
  end
  # rubocop:enable Metrics/MethodLength

  def cover_letter_prompt
    <<~PROMPT
      Tu rédiges une lettre de motivation pour Cyrille PIERRE (excellence opérationnelle et tech/IA, 20 ans
      d'expérience industrielle, ingénieur Arts & Métiers). Le destinataire est un recruteur ou un manager qui a
      publié l'offre fournie en source — pas un client à convaincre commercialement.

      L'offre collée en source peut concerner trois types de poste très différents — identifie lequel avant
      de rédiger, et adapte le positionnement en conséquence :

      1. Poste permanent (CDI) — posture du "Bâtisseur" :
         - Objectif de la lettre : démontrer le fit culturel, une vision à long terme, une capacité à manager
           de manière pérenne
         - Accroche : centrée sur l'entreprise, son actualité, ses projets — montre pourquoi le parcours de
           Cyrille s'inscrit dans cette suite logique
         - Exemples à choisir : des projets de fond (structuration d'un service sur plusieurs années, montée
           en compétences progressive d'une équipe, réduction progressive des coûts)
         - Indicateurs à privilégier : progression dans la durée, fidélisation des équipes, résultats à moyen terme
         - Ton : collaboratif, engagé, orienté transmission
         - Ce que cherche le recruteur : quelqu'un qui va s'intégrer, respecter l'existant avant de le faire
           évoluer, ne pas "faire peur" aux équipes en place — ne sur-vends jamais un profil "de passage" sur
           un poste explicitement pérenne

      2. Poste temporaire / CDD / intérim : positionne Cyrille comme quelqu'un d'opérationnel rapidement, capable
         de produire des résultats mesurables sur une durée définie sans période d'adaptation longue.

      3. Mission de management de transition explicite — posture du "Transformateur" :
         - Objectif de la lettre : démontrer un impact immédiat, une neutralité politique, l'habitude des
           situations complexes — c'est le métier de Cyrille, pas une situation par défaut
         - Accroche : centrée sur une problématique concrète identifiable dans l'offre (baisse de performance,
           départ soudain, fusion, retard de production) que Cyrille sait résoudre
         - Exemples à choisir : des "projets commando" (restructuration rapide, gestion de crise fournisseurs,
           redressement d'une ligne à l'arrêt) plutôt que des projets de fond
         - Indicateurs à privilégier : le temps d'exécution ("en 3 mois..."), les gains immédiats, les
           indicateurs de sortie de crise
         - Ton : direct, pragmatique, axé sur l'action et la décision rapide
         - Ce que cherche le décideur : quelqu'un d'opérationnel dès le premier jour, sans phase d'observation,
           qui sait décider sous pression

      Quel que soit le cas, n'invente jamais la problématique précise de l'entreprise si l'offre ne la
      mentionne pas explicitement — reste alors sur les enjeux génériques décrits dans l'offre.

      RÉALISATIONS DE CYRILLE (à mobiliser pour étayer l'argumentaire, sans citer les identifiants internes type N°XX) :
      #{realisations_str}

      #{cv_context}

      CONSIGNES :
      - C'est Cyrille lui-même qui écrit et signe cette lettre : écris ENTIÈREMENT à la première personne ("je",
        "mon", "j'ai mené"), du tout premier mot jusqu'à la signature. N'écris JAMAIS une phrase à la 3e personne
        du type "Cyrille PIERRE souhaite vous proposer sa candidature" ou "Cyrille PIERRE, ingénieur diplômé de…" —
        même l'accroche d'ouverture doit être au "je" ("Ingénieur diplômé des Arts et Métiers, je…")
      - Montre dès l'accroche que Cyrille a compris le poste précis décrit dans l'offre — pas une formule
        passe-partout qui pourrait s'appliquer à n'importe quel poste
      - Relie explicitement 2 à 3 réalisations de Cyrille aux besoins exprimés dans l'offre
      - Adapte le ton : direct et professionnel, sans formules de motivation creuses ("passionné par", "fort de
        mon expérience", "force de proposition"…)
      - Ne jamais inventer de compétences, chiffres ou expériences non présents dans les sources fournies
      - Le texte final DOIT respecter la structure complète d'une lettre de motivation française, pas seulement
        le corps du texte. Dans cet ordre exact :
        1. Bloc expéditeur : "[Prénom Nom]", "[Adresse]", "[Téléphone]", "[Email]" (Cyrille remplacera ces
           placeholders lui-même)
        2. Ligne destinataire si elle peut être déduite de l'offre (ex. "À l'attention de [nom du recruteur /
           Service Recrutement]"), sinon "[Nom du destinataire]"
        3. Lieu et date : "[Ville], le [date]"
        4. Ligne d'objet : "Objet : Candidature au poste de [intitulé exact du poste tiré de l'offre]"
        5. Formule d'appel adaptée (ex. "Madame, Monsieur," si rien n'indique de nom précis, ou "Monsieur le
           Directeur Général," si l'offre précise le rattachement hiérarchique)
        6. Corps de la lettre : accroche au "je", 2-3 paragraphes de mise en relation profil/besoin (au "je")
        7. Formule de politesse de clôture classique (ex. "Je vous prie d'agréer, [Madame, Monsieur /
           reprendre la formule d'appel], l'expression de mes salutations distinguées.")
        8. Signature : "Cyrille PIERRE"
      - Longueur du corps de la lettre (étape 6 uniquement, hors en-tête/objet/formules) : 250 à 350 mots

      #{structured_output_instructions}
    PROMPT
  end

  def commercial_proposal_prompt
    <<~PROMPT
      Tu rédiges une proposition commerciale courte pour Cyrille PIERRE (consultant indépendant en management de
      transition, excellence opérationnelle et tech/IA, 20 ans d'expérience industrielle), en réponse à un brief
      client. Le destinataire est un décideur qui doit arbitrer un budget — pas un recruteur.

      RÉALISATIONS DE CYRILLE (à mobiliser comme preuves de capacité à délivrer, sans citer les identifiants
      internes type N°XX) :
      #{realisations_str}

      #{cv_context}

      CONSIGNES :
      - C'est Cyrille lui-même qui écrit cette proposition : écris à la première personne ("je propose",
        "j'interviens"), jamais à la 3e personne ("Cyrille PIERRE propose"). Ton moins personnel que pour une
        lettre de motivation : "voici ce que je propose", pas "je suis le candidat idéal"
      - Structure du texte final : reformulation du besoin client (montre l'écoute, pas du remplissage),
        approche proposée (méthode, grandes étapes), 1 à 2 réalisations comparables comme preuve, modalités
        (format de mission, durée indicative, ce qu'il faut côté client)
      - Ne jamais inventer de compétences, chiffres ou expériences non présents dans les sources fournies
      - Pas de survente ni de formules commerciales creuses ("solution sur mesure", "véritable partenaire")
      - Longueur du texte final : 200 à 350 mots

      #{structured_output_instructions}
    PROMPT
  end

  def site_actu_prompt
    <<~PROMPT
      Tu rédiges une actualité courte pour le site web de Cyrille PIERRE, consultant indépendant en management
      de transition, excellence opérationnelle et tech/IA.

      RÉALISATIONS DE CYRILLE (pour mise en contexte si pertinent, sans citer les identifiants internes type N°XX) :
      #{realisations_str}

      CONSIGNES :
      - 100 à 200 mots, ton factuel et clair, à la troisième personne
      - Pas de superlatifs publicitaires ("incroyable", "révolutionnaire"…)
      - Ne jamais inventer de chiffres, dates ou faits non présents dans les sources fournies
      - Réponds uniquement avec le texte de l'actu, sans titre ni commentaire autour
    PROMPT
  end
end
# rubocop:enable Metrics/ClassLength
