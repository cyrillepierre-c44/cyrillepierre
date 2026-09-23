# Builds the prompt for a Generation (based on its kind and sources) and calls the LLM.
class ContentGenerator
  # Proofreading always runs on a fast/cheap Mammouth model regardless of the model chosen
  # for the draft, to keep the extra LLM call quick.
  PROOFREADING_MODEL = Mammouth::DEFAULT_MODEL

  # Les pages de fond du site, qui sont les cibles de lien les plus stables : leurs adresses ne
  # bougent pas, contrairement à celle d'un article qu'on pourrait dépublier.
  SITE_PAGES = {
    "/" => "Profil de Cyrille PIERRE — parcours, chiffres clés et positionnement",
    "/expertise-operationnelle" => "Excellence opérationnelle — Lean, TRS, rebuts, flux, analyse des pertes",
    "/leadership-transformation" => "Leadership et transformation — management de transition, conduite du changement",
    "/tech-ia" => "Tech et IA — digitalisation des processus, outils métier, IA appliquée",
    "/realisations" => "Réalisations — 26 missions détaillées avec leur contexte et leur gain"
  }.freeze

  KIND_PROMPT_METHODS = {
    linkedin_post: :linkedin_post_prompt,
    cover_letter: :cover_letter_prompt,
    commercial_proposal: :commercial_proposal_prompt,
    site_actu: :site_actu_prompt,
    article: :article_prompt,
    executive_brief: :executive_brief_prompt,
    outreach_message: :outreach_message_prompt
  }.freeze

  # Le diagnostic sans l'ordonnance. Un dirigeant qui reçoit le plan d'action essaiera de le faire
  # seul avec son équipe, et échouera le plus souvent ; il n'appellera jamais. La note nomme donc
  # les symptômes, ce qu'ils coûtent, les questions à poser, la preuve que Cyrille a déjà résolu
  # cela ailleurs — et jamais le comment. Contrainte de présence et d'interdiction, que les
  # modèles respectent, contrairement aux comptages.
  NO_PRESCRIPTION_RULE = <<~TXT
    RÈGLE ABSOLUE — LE DIAGNOSTIC SANS L'ORDONNANCE : ce document doit donner envie d'un entretien, pas
    permettre de s'en passer. Tu nommes ce qui cloche, ce que cela coûte, les questions qu'un dirigeant
    devrait poser à son site, et ce que Cyrille a obtenu dans des situations comparables. Tu ne donnes
    JAMAIS le comment : aucun plan d'action, aucune liste d'étapes, aucune méthode nommée avec son mode
    d'emploi (pas de « mettre en place un chantier 5S », « instaurer des routines quotidiennes »,
    « déployer un tableau de bord TRS »), aucun outil, aucun ordre de priorité des leviers, aucun
    calendrier de mise en œuvre. Un résultat passé se cite avec son chiffre et son contexte, jamais
    avec la manière dont il a été obtenu. Si une phrase explique comment faire, supprime-la.
  TXT

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

  # Only injected into public-facing content (LinkedIn posts, site actus) — cover letters and
  # commercial proposals legitimately name past employers/clients as credibility/references.
  ANONYMIZE_COMPANIES_RULE = <<~TXT
    CONFIDENTIALITÉ — RÈGLE ABSOLUE : ce contenu est public. Ne mentionne JAMAIS le nom réel d'une entreprise,
    marque, groupe ou enseigne (même si un nom apparaît dans les réalisations ou le CV ci-dessus). Décris
    l'entreprise de façon générique à partir de son secteur et de sa taille (ex. "une usine agroalimentaire
    filiale d'un groupe international", "un sous-traitant pharmaceutique de taille intermédiaire", "une PME
    industrielle"), jamais par son nom. D'anciens clients ou employeurs ne souhaitent pas voir l'état ou la
    performance de leur outil industriel discutés publiquement sous leur nom — reste sur des faits et des
    chiffres, jamais sur l'identité de l'entreprise.
  TXT

  # La note de diagnostic ne se relit plus à la main : ses chiffres sont comparés aux sources par
  # FigureAudit, et le modèle ne reprend la plume que sur ce que l'audit a signalé. Quand l'analyse
  # et le brief se contredisent, une règle de préséance tranche (chiffres → analyse, faits de
  # contexte → brief) et le modèle liste ce qu'il a tranché sous ce marqueur, que Ruby verse au
  # journal. Une première version bloquait la génération : le 18/09/2026 elle a arrêté la note 203
  # sur une date d'inauguration que le brief tenait de la presse — la note n'a rien à attendre.
  DISCREPANCY_MARKER = "###ECARTS###"
  JOURNAL_MARKER = "###JOURNAL###"

  FIGURE_CORRECTION_INSTRUCTIONS = <<~PROMPT
    Tu corriges une note déjà rédigée, sans la réécrire. Une relecture automatique a comparé chacun de ses
    chiffres aux sources ; ceux listés ci-dessous n'y figurent pas. Pour chacun :
    - s'il vient d'une erreur de recopie, d'unité ou d'arrondi, remplace-le par le chiffre exact de la source ;
    - s'il résulte d'un calcul à partir de chiffres des sources, garde-le et donne sa formule ;
    - sinon, retire-le ; si la phrase ne dit plus rien sans lui, retire la phrase entière plutôt que de
      laisser une formule creuse (« une petite réduction représente des économies significatives »).
    Un chiffre gardé sans formule vérifiable sera retiré de sa phrase par la relecture suivante : garder n'est
    pas une option par défaut. Quand des chiffres proches existent dans les sources, ils sont indiqués entre
    parenthèses : c'est presque toujours l'un d'eux qui était visé.
    Ne change RIEN d'autre : ni le reste du texte, ni la structure, ni les lignes de marqueurs ###…###.
    Réponds avec le texte complet corrigé, puis, sur une ligne seule, #{JOURNAL_MARKER}, puis une ligne par
    chiffre gardé comme calcul, au format « chiffre = formule » où la formule n'emploie que des chiffres des
    sources et les opérateurs + − × / (ex. « 307 K€ = 30,7 M€ × 1 % »). Rien d'autre après le journal.
  PROMPT

  # Dernier filet, phrase par phrase, sur le modèle rapide : ce que la passe de correction a gardé
  # sans formule est réécrit sans le chiffre ou avec le chiffre source voisin. Ruby vérifie la
  # phrase rendue avant de la substituer ; sinon la ligne « non résolu » reste dans le journal.
  SENTENCE_REWRITE_INSTRUCTIONS = <<~PROMPT
    Tu réécris UNE phrase d'une note, rien d'autre. Le chiffre indiqué n'apparaît dans aucune source : s'il
    correspond à l'un des chiffres proches listés, remplace-le par celui-ci ; sinon réécris la phrase sans ce
    chiffre, en gardant son sens, sa langue, son ton et sa mise en forme (gras, liens). N'ajoute aucun autre
    chiffre. Réponds par la phrase seule, sans guillemets ni commentaire.
  PROMPT

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
    draft = ask(new_chat.with_instructions(system_prompt), user_prompt)
    draft = audit_figures(draft) if generation.audited?
    generation.update!(output: proofread(draft), status: :generated)
    generation
  rescue StandardError => e
    Rails.logger.error "ContentGenerator error: #{e.class} — #{e.message}"
    generation.update!(output: "Erreur lors de la génération : #{error_summary(e)}", status: :draft)
    generation
  end

  private

  attr_reader :generation

  def new_chat
    Mammouth.chat(model: generation.llm_model)
  end

  # Toujours en flux : la passerelle Mammouth est derrière Cloudflare, qui coupe toute requête
  # restée muette 100 secondes (erreur 524). Une note de diagnostic sur Fable 5.1 réfléchit
  # plus longtemps que ça avant d'écrire le premier mot — le 18/09/2026, la régénération de la
  # note 203 est morte ainsi à 125 s. En flux, les premiers octets partent dès le début et la
  # connexion vit jusqu'au dernier ; RubyLLM rend le message complet une fois le flux terminé.
  def ask(chat, prompt)
    chat.ask(prompt) { |_chunk| nil }.content.to_s
  end

  # Une erreur de passerelle arrive en page HTML entière ; n'en garder que le titre.
  def error_summary(error)
    title = error.message[%r{<title>(.*?)</title>}m, 1]
    title ? "passerelle Mammouth — #{title.strip}" : error.message.truncate(300)
  end

  def proofread(text)
    return text if text.blank?

    ask(Mammouth.chat(model: PROOFREADING_MODEL).with_instructions(PROOFREADING_INSTRUCTIONS), text)
  rescue StandardError => e
    Rails.logger.error "ContentGenerator proofread error: #{e.class} — #{e.message}"
    text
  end

  # Le brouillon passe au crible de FigureAudit ; seuls les chiffres absents des sources repartent
  # au modèle, avec obligation de corriger, de retirer ou de justifier par une formule que Ruby
  # recalcule. Le journal de ce qui s'est passé prend la place de l'ancienne section à vérifier,
  # précédé des écarts brief / analyse que le modèle dit avoir tranchés.
  def audit_figures(draft)
    draft, discrepancies = draft.split(DISCREPANCY_MARKER, 2)
    sections = sections_of(draft.to_s)
    return draft.to_s if sections.nil?

    audit = FigureAudit.new(audit_sources)
    flagged = audit.unsourced(audited_text(sections))
    if flagged.empty?
      clean = "Aucune correction : chaque chiffre de la note figure dans les sources."
      return rebuild(sections, discrepancies_journal(discrepancies) + clean)
    end

    corrected, formulas = correct_figures(draft, flagged, audit)
    sections = sections_of(corrected) || sections
    remaining = audit.unsourced(audited_text(sections))
    rewritten = rewrite_unresolved(sections, audit, remaining, formulas)
    remaining = audit.unsourced(audited_text(sections))
    rebuild(sections,
            discrepancies_journal(discrepancies) + journal(audit, flagged, remaining, formulas, rewritten))
  end

  def supported?(audit, figure, formulas)
    formulas.any? { |left, right| audit.same_figure?(figure, left) && audit.supports?(figure, right) }
  end

  def rewrite_unresolved(sections, audit, remaining, formulas)
    remaining.reject { |figure| supported?(audit, figure, formulas) }.select do |figure|
      key, sentence = sentence_with(sections, figure.raw)
      next false unless sentence

      rewritten = rewrite_sentence(sentence, figure, audit.nearby(figure))
      next false unless acceptable_rewrite?(audit, sentence, figure, rewritten)

      sections[key] = sections[key].sub(sentence, rewritten)
    end
  end

  # La phrase réécrite ne porte plus aucun chiffre non sourcé, et garde tous les autres chiffres
  # de la phrase d'origine : retirer un chiffre faux ne doit pas emporter un chiffre juste.
  def acceptable_rewrite?(audit, sentence, figure, rewritten)
    return false if rewritten.blank? || audit.unsourced(rewritten).any?

    audit.figures(sentence).reject { |other| other.raw == figure.raw }
                           .all? { |other| audit.same_figure?(other, rewritten) }
  end

  # Une phrase s'arrête à une ponctuation suivie d'un blanc, ou à la fin de ligne : le point de
  # « €30.7m » n'en termine pas une.
  def sentence_with(sections, raw)
    %i[final short].each do |key|
      sentence = sections[key].to_s.split(/(?<=[.!?])\s+|\n+/).find { |candidate| candidate.include?(raw) }
      return [key, sentence] if sentence
    end
    nil
  end

  def rewrite_sentence(sentence, figure, nearby)
    question = "PHRASE :\n#{sentence}\n\nCHIFFRE ABSENT DES SOURCES : #{figure.raw}\n" \
               "CHIFFRES PROCHES DANS LES SOURCES : #{nearby.presence&.join(', ') || 'aucun'}"
    ask(Mammouth.chat(model: PROOFREADING_MODEL).with_instructions(SENTENCE_REWRITE_INSTRUCTIONS), question).strip
  end

  def discrepancies_journal(text)
    lines = text.to_s.lines.map(&:strip).reject(&:empty?).grep_v(/\Aaucun\.?\z/i)
    return "" if lines.empty?

    "Écarts entre le brief et l'analyse, tranchés par la règle (chiffres des comptes → analyse ; faits de " \
      "contexte → brief) :\n#{lines.map { |line| line.start_with?('-') ? line : "- #{line}" }.join("\n")}\n\n"
  end

  def journal(audit, flagged, remaining, formulas, rewritten)
    lines = flagged.reject { |figure| remaining.any? { |r| r.raw == figure.raw } }.map do |figure|
      if rewritten.any? { |r| r.raw == figure.raw }
        "- Corrigé par réécriture de la phrase : #{figure.raw}"
      else
        "- Corrigé ou retiré : #{figure.raw}"
      end
    end
    remaining.each do |figure|
      formula = formulas.find { |left, right| audit.same_figure?(figure, left) && audit.supports?(figure, right) }
      lines << if formula
                 "- Conservé, calcul vérifié : #{figure.raw} = #{formula.last}"
               else
                 "- Non résolu, à contrôler : #{figure.raw}"
               end
    end
    "Relecture automatique des chiffres contre l'analyse jointe, le brief, le catalogue et le CV.\n" \
      "#{lines.join("\n")}"
  end

  def correct_figures(draft, flagged, audit)
    listed = flagged.map do |figure|
      nearby = audit.nearby(figure)
      nearby.empty? ? "- #{figure.raw}" : "- #{figure.raw} (chiffres proches dans les sources : #{nearby.join(', ')})"
    end.join("\n")
    instructions = "#{FIGURE_CORRECTION_INSTRUCTIONS}\nCHIFFRES ABSENTS DES SOURCES :\n#{listed}\n\n" \
                   "SOURCES :\n#{audit_sources.join("\n\n")}"
    reply = ask(new_chat.with_instructions(instructions), draft)
    corrected, journal = reply.split(JOURNAL_MARKER, 2)
    formulas = journal.to_s.lines.filter_map do |line|
      left, right = line.sub(/\A\s*[-•*]\s*/, "").split("=", 2)
      [left.strip, right.strip] if right.present?
    end
    [corrected.to_s, formulas]
  end

  def audit_sources
    @audit_sources ||= [generation.input_text, generation.financial_analysis,
                        (extracted_file_text if generation.source_file.attached?),
                        (scraped_url_text if generation.input_url.present?), realisations_str, cv_context,
                        Date.current.year.to_s].compact_blank
  end

  def sections_of(text)
    return nil unless text.include?(Generation::SECTION_MARKERS[:final])

    Generation.new(kind: generation.kind, output: text).sections
  end

  def audited_text(sections)
    sections.values_at(:final, :short).compact.join("\n")
  end

  def rebuild(sections, journal)
    Generation::SECTION_MARKERS.filter_map do |key, marker|
      content = key == :verify ? journal : sections[key]
      "#{marker}\n#{content}" if content.present?
    end.join("\n\n")
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
    if generation.financial_analysis.present?
      parts << "ANALYSE FINANCIÈRE VALIDÉE (seule source des chiffres) :\n#{generation.financial_analysis}"
    end
    if generation.extra_instructions.present?
      parts << "Instructions complémentaires :\n#{generation.extra_instructions}"
    end
    parts.join("\n\n").presence ||
      "Aucune source fournie — génère un contenu générique à partir du profil de Cyrille ci-dessus."
  end

  def scraped_url_text
    @scraped_url_text ||= UrlScraper.call(generation.input_url)
  rescue UrlScraper::UnsafeUrlError => e
    "(impossible de récupérer cette URL : #{e.message})"
  end

  def extracted_file_text
    @extracted_file_text ||= FileTextExtractor.call(generation.source_file)
  end

  # Le catalogue se rend lui-même (voir RealisationCatalog.to_prompt), périmètre sémantique
  # compris : c'est là que se joue l'interdiction de rattacher un chiffre au sujet voisin.
  def realisations_str
    RealisationCatalog.to_prompt(:named)
  end

  # Same catalogue, but described by sector/scale instead of by company name — used for the
  # public-facing kinds (LinkedIn posts, site actus) so the real employer/client name never
  # even reaches the prompt, on top of the explicit ANONYMIZE_COMPANIES_RULE instruction.
  def anonymized_realisations_str
    RealisationCatalog.to_prompt(:anonymized)
  end

  delegate :locked_realisation, to: :generation

  # When no source was provided, Generation#assign_auto_realisation (or a manual choice in the
  # form) has already fixed a single realisation — frame the post around it and its semantic_scope
  # instead of letting the model pick one after inventing a topic on its own.
  def linkedin_realisations_block
    return locked_realisation_block if locked_realisation

    <<~TXT
      RÉALISATIONS DE CYRILLE (à citer si pertinent, sans les identifiants internes type N°XX) :
      #{anonymized_realisations_str}

      Avant de choisir laquelle citer, vérifie que son éventuel "semantic_scope" correspond bien au sujet ou au
      brief fourni — certaines réalisations précisent explicitement pour quels sujets les utiliser ou ne pas
      les utiliser.
    TXT
  end

  def locked_realisation_block
    r = locked_realisation
    scope_line = "Cadre d'utilisation : #{r[:semantic_scope]}" if r[:semantic_scope].present?
    <<~TXT
      RÉALISATION À UTILISER POUR CE POST (obligatoire, n'en choisis pas une autre) :
      #{r[:titre]} — #{r[:scale]}, #{r[:type_orga]} — #{r[:resultat]}
      #{scope_line}
    TXT
  end

  def linkedin_realisation_choice_consigne
    return if locked_realisation

    "- Choisis une réalisation différente de celles déjà utilisées dans les posts récents listés ci-dessus, " \
      "sauf si aucune autre ne convient au sujet"
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
      excellence opérationnelle et tech/IA. Ton style : direct, concret, pas de jargon creux, quelques emojis
      ciblés (jamais aucun, jamais en excès — voir la consigne précise plus bas).

      #{ANONYMIZE_COMPANIES_RULE}

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

      #{linkedin_realisations_block}

      #{cv_context}

      #{recent_posts_context}

      #{linkedin_source_article_block}

      CANEVAS À SUIVRE (adapte la longueur de chaque partie au sujet, mais respecte cet enchaînement) :
      1. Hook — 1 à 2 lignes qui donnent envie de lire la suite (chiffre surprenant, affirmation tranchée, question
         directe). Pas de mise en contexte avant le hook.
      2. Contexte — la situation de départ, le problème ou la contrainte rencontrée, en 2-4 lignes concrètes.
      3. Résultat — ce qui a été fait et obtenu, avec les chiffres/faits réels fournis dans les sources.
      4. Ouverture — la question ouverte ou l'invitation à réagir qui clôt le post (voir consignes ci-dessous).

      MISE EN FORME :
      - Le gras (markdown **comme ceci**) est réservé à EXACTEMENT 2 passages dans tout le post, jamais plus,
        jamais moins : (1) le chiffre ou résultat le plus marquant du Hook, (2) le chiffre ou résultat le plus
        marquant du paragraphe Résultat. Rien d'autre ne doit être en gras.
        - Un passage en gras = un chiffre avec son unité ("**240 K€/an**", "**TRS +8%**") ou un terme technique
          isolé de 1 à 3 mots ("**micro-arrêts**") — jamais un verbe, jamais "sujet + verbe + complément"
        - Mauvais exemple (à ne jamais reproduire) : "**réduire de moitié les temps d'arrêt**" (c'est une
          proposition entière, pas un mot-clé) ou "**240 000 € par an économisés**" (le verbe ne doit pas être
          inclus : écris plutôt "**240 000 €/an**" tout court)
        - Bon exemple : "Résultat : **240 K€/an** économisés grâce à une digitalisation du suivi TRS."
      - 3 à 5 emojis ciblés dans tout le post, jamais en décoration : un emoji n'est légitime qu'attaché à un
        chiffre, un résultat ou une étape clé (ex. "📊 +8% de TRS", "🎯 l'objectif"), jamais en début de chaque ligne
        ni pour faire joli

      CONSIGNES :
      - 150 à 250 mots
      - Phrases courtes, retours à la ligne fréquents (format LinkedIn, pas de gros pavés)
      #{linkedin_realisation_choice_consigne}
      - Quand c'est pertinent, traduis le résultat opérationnel en langage compréhensible par un décideur financier
        (ex. "moins d'arrêts machine non planifiés" → "un risque opérationnel mieux maîtrisé"), MAIS uniquement à
        partir des chiffres et faits réellement fournis dans les réalisations ou les sources — jamais de ratio,
        pourcentage ou indicateur financier (EBITDA, ROI, WACC, multiple de valorisation…) qui n'est pas
        explicitement donné dans les sources
      - N'invente et ne cite jamais de résultat financier précis (chiffre, %, point) pour une entreprise nommée
        si ce chiffre ne figure pas dans les réalisations fournies — en cas de doute, reste qualitatif
        ("a contribué à réduire les coûts", sans inventer le montant) plutôt que d'inventer un chiffre
      - L'accroche ne doit JAMAIS dramatiser un chiffre au-delà de ce que dit la source : si une réalisation
        indique "−50% d'arrêts non identifiés", n'écris jamais que les arrêts ont "disparu" ou "atteint zéro" —
        reprends le chiffre exact ("réduits de moitié"), même dans l'accroche. Relis ton propre texte avant de
        répondre : si un chiffre apparaît à deux endroits différents du post, vérifie qu'il est rigoureusement
        identique aux deux endroits
      - Termine par une question ouverte ou une invitation à réagir, sans "lien en commentaire" artificiel et
        sans formule de growth-hacking creuse (pas de "MP-moi le mot clé X, je t'envoie mon template")
      - Pas de hashtags excessifs (3 maximum, à la fin)
      - Ne jamais inventer de chiffres ou de faits non fournis dans les sources

      AVANT DE RÉPONDRE, vérifie ton brouillon sur ces deux points précis (corrige-le si besoin avant de
      répondre) :
      1. Compte les emojis : il en faut ENTRE 3 ET 5, jamais zéro. S'il y en a moins de 3, ajoute-en sur un
         chiffre, un résultat ou une étape clé du texte.
      2. Compte les passages en gras (texte entre **...**) : il en faut EXACTEMENT 2, ni plus ni moins. Si tu
         en as plus de 2, retire les marqueurs ** des passages en trop. Si un passage en gras contient un verbe
         ou plus de 3 mots, raccourcis-le au seul chiffre ou mot-clé qu'il contient (ex. "**240 000 €
         économisés**" devient "**240 000 €**").

      Réponds uniquement avec le texte du post, sans titre ni commentaire autour.
    PROMPT
  end

  # Quand le post promeut un article, il change de nature : son but n'est plus de susciter une
  # réaction dans le fil, mais de faire cliquer. Les consignes générales interdisent de pousser
  # un lien — c'est délibéré pour les posts ordinaires, et c'est ici qu'on lève l'interdiction.
  def linkedin_source_article_block
    article = generation.source_article
    return "" if article.blank?

    <<~BLOCK
      CE POST PROMEUT UN ARTICLE DU SITE — ces consignes l'emportent sur celles qui interdisent
      de pousser un lien :
      - Titre de l'article : #{article.display_title}
      - Adresse : #{article.public_url}

      Texte intégral de l'article, qui est la SEULE matière du post :
      #{ArticleFormatter.plain_text(article.output)}

      Comment procéder :
      - Choisis UNE idée de l'article, la plus contre-intuitive, et construis le post autour d'elle.
        Ne résume pas l'article : un résumé complet supprime la raison de le lire.
      - Le post doit tenir debout seul. Quelqu'un qui ne clique pas doit quand même avoir appris
        quelque chose — c'est ce qui donne envie de cliquer.
      - Remplace l'Ouverture du canevas par une invitation à lire l'article, en une phrase, puis
        l'adresse seule sur sa dernière ligne. Pas de « lien en commentaire », pas de « 👇 ».
      - N'invente rien qui ne soit pas dans l'article.
    BLOCK
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

  # La note de diagnostic dirigeant : la seule pièce du Studio qui parte du chiffre. Elle combine
  # l'analyse financière collée en source (validée par Cyrille avant génération), la fiche prospect,
  # le catalogue avec les vrais noms (document privé), le CV et les articles publiés comme preuves.
  def executive_brief_prompt
    mode = executive_brief_mode
    <<~PROMPT
      Tu rédiges une NOTE DE DIAGNOSTIC pour Cyrille PIERRE, manager de transition et consultant en excellence
      opérationnelle (20 ans d'industrie, ingénieur Arts & Métiers, formation ICCF HEC en analyse financière),
      à l'attention du dirigeant, du directeur de pôle ou du board d'une entreprise industrielle. Ce document
      part de ce que l'entreprise montre d'elle-même — #{mode[:matter]} — et le relie à ce qui se passe dans
      ses ateliers. Son seul but : obtenir un entretien.

      #{NO_PRESCRIPTION_RULE}

      LE LECTEUR : il rend des comptes en EBITDA, en dette et en trésorerie, pas en TRS. Chaque constat est
      d'abord dit dans son langage (marge, coût par point de chiffre d'affaires, mois de trésorerie), puis relié
      en une phrase à sa cause d'atelier probable, posée comme une hypothèse ou une question — jamais comme une
      certitude sur une usine que Cyrille n'a pas visitée.

      RÉALISATIONS DE CYRILLE (preuves à citer avec leurs chiffres et leur contexte réel — document privé, les
      noms d'entreprises sont autorisés — sans jamais décrire la méthode ; sans les identifiants internes N°XX) :
      #{realisations_str}

      ADRESSE PUBLIQUE DE CHAQUE RÉALISATION (sa fiche illustrée sur le site) — chaque réalisation citée dans la
      note porte un lien markdown vers sa fiche, posé sur le nom de l'entreprise ou sur le résultat, jamais sur un
      « ici » : #{realisation_links}

      #{cv_context}

      #{published_articles_block}

      #{mode[:sources]}
      Une relecture automatique comparera ensuite chaque chiffre de la note aux sources : un chiffre inventé,
      arrondi à sa façon ou mal recopié sera retiré ; un chiffre calculé n'est gardé que si la note montre son
      calcul à partir de chiffres des sources (« un point de chiffre d'affaires, soit 307 K€ »).
      ⚠ Le brief contient aussi des NOTES INTERNES de Cyrille — consignes à lui-même, jugements sur le lecteur ou
      sur l'entreprise, historique social, allusions à l'actionnaire, tactique d'approche. Elles servent à
      comprendre la situation, JAMAIS à être reprises : rien de ce qui est écrit pour Cyrille ne passe dans le
      document, ni en substance ni en formulation. Le lecteur ne doit trouver aucune phrase qui parle de lui, de
      son fonds ou de son passé social autrement que par les chiffres de ses comptes.
      ⚠ Les réalisations se citent avec le contexte EXACT du catalogue et du CV : aucun détail technique ajouté
      (classe de salle blanche, type de contrôle, équipement), aucune description de la manière dont le résultat
      a été obtenu. Un résultat = un contexte + un chiffre + une durée, rien d'autre.

      LE CADRAGE — MONTRER LA SORTIE, PAS LA CATASTROPHE : un dirigeant qui lit ses pertes sous la plume d'un
      inconnu se braque avant la deuxième page. Les chiffres restent exacts, c'est l'angle qui change. L'ouverture
      reconnaît d'abord ce qui a été accompli, tel que l'analyse le montre (une croissance, un investissement mené
      à bien, une capacité installée, un besoin en fonds de roulement maîtrisé…), puis dit en une phrase la tension
      (la marge ou la trésorerie n'a pas encore suivi), puis annonce que les comptes montrent aussi où se trouve le
      résultat à retrouver. Chaque constat se termine par ce qu'il rend possible : on parle de résultat à retrouver,
      de marge à reconstituer, de trésorerie à libérer — jamais d'alerte, de danger, de dette insoutenable ni de
      faillite. L'optimisme porte sur le potentiel du site, jamais sur la personne du lecteur : aucune flatterie.

      STRUCTURE DE LA NOTE (texte final), en markdown avec des titres « ## », #{mode[:length]}, sans titre
      de document en tête (le PDF porte le sien) — les montants s'écrivent arrondis comme dans l'analyse
      (30,7 M€ ou €30.7m, jamais 30 729 278 €) :
      1. Un paragraphe d'ouverture, trois ou quatre phrases : ce que l'entreprise a accompli d'après
         #{mode[:evidence]}, la tension en une phrase, et la raison de cette note — le résultat que
         #{mode[:evidence]} laisse entrevoir.
      2. « ## #{mode[:findings_title]} » — #{mode[:findings]}, chacun en un paragraphe court, dans le langage
         du lecteur, et chacun refermé par ce qu'il rend possible.
      3. « ## Ce que chaque mois d'attente coûte » — #{mode[:cost]}
      4. « ## Les questions à poser à votre site » — #{mode[:questions]}, dont les réponses révèlent les
         causes sans les nommer ni indiquer quoi faire.
      5. « ## Ce que j'ai obtenu dans des situations comparables » — deux ou trois réalisations, chacune avec
         son contexte, son chiffre et sa durée ; quand un résultat est un résultat de site obtenu par plusieurs
         chantiers de front, le dire. Aucune méthode.
      6. « ## Ce que produirait une mission » — en résultats attendus et en gouvernance (qui décide, à quel
         rythme, comment le dirigeant garde la main), jamais en méthode ni en étapes ; une phase de diagnostic
         sur place de quelques semaines, puis la mission. Pas de prix.
      7. Une phrase de clôture qui propose un échange de trente minutes.

      TON : sobre, direct, factuel, à la première personne. Aucun superlatif, aucune formule de vente, aucune
      liste de compétences. Le document doit pouvoir être lu en dix minutes par quelqu'un qui n'a pas le temps.

      MISE EN RELIEF : dans chaque paragraphe de constat et dans chaque réalisation citée, UN seul passage en gras
      (**ainsi**), le chiffre clé avec son unité — jamais une phrase entière, jamais deux passages dans le même
      paragraphe. Les liens (réalisations, articles) sont en markdown [texte](adresse) : ils sont cliquables dans
      le PDF, une adresse nue ne l'est pas.

      EXACTITUDE DES QUALIFICATIFS : ne dis jamais plus que la source. Des comptes « déposés » ne sont pas
      « audités » ; un chiffre « calculé » n'est pas « mesuré ». Ce que le brief présente comme une hypothèse
      (« probablement », « à confirmer », « si … ») reste une hypothèse dans le document, au conditionnel ou sous
      forme de question. L'actionnaire ou le fonds ne se nomme jamais : « vos actionnaires », pas leur nom.

      COHÉRENCE : si la note dit qu'un résultat vient de plusieurs chantiers menés de front, aucune phrase ne
      parle d'un levier unique qui changerait tout. Relis la note en entier avant de répondre pour qu'aucune
      phrase n'en contredise une autre.

      LANGUE ET GLOSSAIRE : si les instructions demandent une autre langue, écris nativement dans cette langue —
      aucun mot français ne subsiste dans un texte anglais — et traduis le vocabulaire industriel du catalogue
      ainsi : TRS → OEE · aléas → unplanned disruptions (jamais « incidents », qui se lit comme des accidents) ·
      rebuts → scrap · gisement → pocket of value · façonnier / sous-traitant pharmaceutique → CDMO · CODIR →
      executive committee · IRP → employee representatives · 3×8 → three-shift operation · amélioration continue
      → continuous improvement · main-d'œuvre → labour · BFR → working capital · EBE → EBITDA · DAP →
      depreciation · directeur de site → site head · manager de transition → interim manager.

      FORMAT DE RÉPONSE OBLIGATOIRE — trois sections, chacune précédée de son marqueur exact, seul sur sa
      ligne, dans cet ordre :

      #{Generation::SECTION_MARKERS[:final]}
      La note complète, selon la structure ci-dessus.

      #{Generation::SECTION_MARKERS[:personalize]}
      Liste à puces de ce que Cyrille doit relire ou adapter avant envoi (nom du destinataire, formulations
      à ajuster à ce qu'il sait du contexte). Aucune liste de chiffres à vérifier : la relecture des chiffres
      est automatique.

      #{Generation::SECTION_MARKERS[:short]}
      La LETTRE D'ACCOMPAGNEMENT de la note, 120 à 180 mots, adressée au destinataire, qui nomme la source
      publique d'où vient le signal (une annonce, un article, des comptes déposés) et qui donne envie d'ouvrir
      la note sans en répéter le contenu.

      #{DISCREPANCY_MARKER}
      Une ligne par écart entre le brief et l'analyse que tu as tranché, avec la valeur retenue et sa source
      (« Date de la ligne : novembre 2024, brief, contre novembre 2023 dans l'analyse »), ou « Aucun. ».

      N'écris rien avant le premier marqueur ni après la dernière section.
    PROMPT
  end

  # Deux notes, selon ce que Cyrille possède. Avec l'analyse financière collée dans son champ, la note
  # lit les comptes et chaque chiffre en vient — le brief n'est que du contexte, et une contradiction
  # chiffrée entre les deux arrête tout. Sans analyse, la note se tricote avec ce que l'entreprise
  # montre d'elle-même (annonce, article, comptes résumés) : moins de constats, pas de section coût
  # sans chiffre pour la porter, davantage de questions — c'est là qu'elle prend sa valeur.
  def executive_brief_mode
    if generation.financial_analysis.present?
      {
        matter: "ses comptes, lus dans l'analyse financière validée",
        sources: <<~TXT.strip,
          SOURCES — MODE COMPTES : l'ANALYSE FINANCIÈRE VALIDÉE (bloc « ANALYSE FINANCIÈRE VALIDÉE » du
          message) est la SEULE source des chiffres sur l'entreprise : elle a été vérifiée deux fois par l'outil
          d'analyse de Cyrille. Le texte collé (brief prospect) sert au contexte : le signal public,
          l'interlocuteur, les chantiers pressentis — jamais aux chiffres. Un chiffre présent dans le brief et
          absent de l'analyse ne sert pas. PRÉSÉANCE quand les deux se contredisent, à appliquer sans poser de
          question : pour tout ce qui vient des comptes (chiffre d'affaires, marges, dette, trésorerie, BFR,
          ratios, exercices), l'analyse l'emporte et la valeur du brief est ignorée ; pour les faits de contexte
          que les comptes ne contiennent pas (date d'un événement, nature des produits, actionnaire, effectif,
          interlocuteurs), le brief l'emporte, parce qu'il les tient de sources publiques nommées, et la note ne
          reprend pas la formulation contraire de l'analyse. N'ajoute aucun chiffre qui ne figure pas dans
          l'analyse.
        TXT
        length: "900 à 1300 mots",
        evidence: "ses comptes",
        findings_title: "Ce que vos comptes disent",
        findings: "trois constats chiffrés au plus",
        cost: "un ordre de grandeur par constat, calculé uniquement à partir des chiffres de l'analyse " \
              "(ex. la valeur d'un point de chiffre d'affaires), le calcul montré, avec la prudence qui " \
              "convient : ce sont des ordres de grandeur, pas des promesses.",
        questions: "cinq questions au plus"
      }
    else
      {
        matter: "une annonce, un article, des comptes résumés, un signal public repris dans le brief",
        sources: <<~TXT.strip,
          SOURCES — MODE SIGNAUX PUBLICS : aucune analyse financière n'est fournie. La seule matière chiffrée est
          le texte collé (brief prospect : annonce, article, comptes résumés, effectif, signal public). La note
          ne prétend pas avoir lu les comptes : elle part de ce que l'entreprise montre d'elle-même et pose les
          questions que ces signaux appellent. N'ajoute aucun chiffre qui ne figure pas dans le brief ; un
          constat sans chiffre se formule comme une observation, jamais comme une mesure.
        TXT
        length: "700 à 1000 mots",
        evidence: "ce qu'elle montre d'elle-même",
        findings_title: "Ce que l'on voit de l'extérieur",
        findings: "deux constats au plus, chacun rattaché au signal public qui le fonde",
        cost: "seulement si un chiffre du brief permet un ordre de grandeur (un effectif, un chiffre " \
              "d'affaires, un investissement annoncé), le calcul montré ; sinon, omets la section entière " \
              "plutôt que d'y mettre un chiffre venu d'ailleurs.",
        questions: "jusqu'à sept questions — c'est ici que la note prend sa valeur quand les comptes manquent"
      }
    end
  end

  # Trois lignes pour obtenir une réponse, jamais pour vendre : la source publique nommée (c'est
  # l'obligation d'information du RGPD, et ce qui rend l'approche crédible), une seule réalisation
  # avec son chiffre exact, une question. Ruby relit ensuite les chiffres comme pour la note.
  def outreach_message_prompt
    <<~PROMPT
      Tu rédiges le PREMIER MESSAGE DE PRISE DE CONTACT de Cyrille PIERRE, manager de transition et consultant
      en excellence opérationnelle à Lyon, à un décideur (dirigeant, directeur de site, directeur industriel,
      DRH) d'une entreprise industrielle repérée par un signal public : une annonce, un article, un avis au
      BODACC, des comptes déposés. Son seul but : obtenir une réponse. Il précède toute note ou proposition.

      LE BRIEF collé vient de la fiche prospect : le signal et sa source, la lecture, la réalisation comparable,
      une accroche proposée, et des NOTES INTERNES de Cyrille (jugements, tactique) qui ne se reprennent jamais,
      ni en substance ni en formulation.

      RÈGLES :
      - Nomme la source publique du signal avec sa date, dès la première phrase (« j'ai vu votre annonce sur
        Indeed du 9 septembre », « j'ai lu dans Le Progrès du 15 septembre ») : c'est l'obligation d'information
        du RGPD, et ce qui rend l'approche crédible. Jamais « je suis tombé sur », jamais de source inventée.
      - UNE seule réalisation comparable, celle du brief ou la plus proche du catalogue ci-dessous, avec son
        contexte et son chiffre EXACTS, jamais la manière dont le résultat a été obtenu. Aucun chiffre sur
        l'entreprise contactée qui ne soit dans le brief.
      - Une hypothèse posée comme une QUESTION sur ce que l'entreprise vit, jamais une affirmation sur une usine
        que Cyrille n'a pas visitée. Aucun plan d'action, aucune méthode, aucun outil.
      - Aucune flatterie, aucun « j'espère que vous allez bien », aucun « n'hésitez pas », aucun « je me permets »,
        aucune pièce jointe annoncée, aucun lien sauf, si un article publié ci-dessous traite du sujet exact, son
        adresse en fin de message. Vouvoiement. Ton d'un pair, direct, sobre.
      - Le destinataire : si le brief le nomme, adresse-toi à lui ; sinon commence par « Bonjour [Prénom], » et
        signale-le dans les points à personnaliser.
      - Si le brief dit POURQUOI ce destinataire (une nomination au BODACC, un article qui le cite), dis-le en
        une proposition avec la source et sa date : c'est ce qui justifie qu'on lui écrive à lui.
      - DESTINATAIRE AU-DESSUS DU SITE (direction groupe, vice-président des opérations, président de l'entité,
        responsable multi-sites) : à ce niveau le message vise autant un transfert vers la bonne personne
        qu'une réponse. La question porte alors sur qui pilote le site pendant la recherche et sur l'utilité
        d'un relais de direction jusqu'à l'arrivée du titulaire — jamais sur le détail de l'atelier, qu'il ne
        suit pas. Le message reste aussi court, la réalisation comparable s'énonce en une demi-phrase.
      - Langue : français, sauf instruction contraire.

      RÉALISATIONS DE CYRILLE (document privé, noms réels autorisés) :
      #{realisations_str}

      #{cv_context}

      #{published_articles_block}

      FORMAT DE RÉPONSE OBLIGATOIRE — trois sections, chacune précédée de son marqueur exact, seul sur sa
      ligne, dans cet ordre :

      #{Generation::SECTION_MARKERS[:final]}
      Le MESSAGE LINKEDIN : trois à cinq phrases, 90 mots au plus, 550 caractères au plus, sans objet ni
      signature (LinkedIn les porte). Ses deux premières phrases doivent tenir seules en 300 caractères, pour
      servir de note d'invitation si le destinataire n'est pas encore en relation.

      #{Generation::SECTION_MARKERS[:personalize]}
      Liste à puces de ce que Cyrille doit relire ou adapter avant envoi (prénom, poste exact du destinataire,
      formulation à ajuster à ce qu'il sait). Aucune liste de chiffres à vérifier : la relecture des chiffres
      est automatique.

      #{Generation::SECTION_MARKERS[:short]}
      La VARIANTE EMAIL : première ligne « Objet : … » (60 caractères au plus, qui nomme la source), puis le
      corps, 120 à 160 mots, même fond que le message LinkedIn, et la signature sur quatre lignes :
      #{SiteIdentity::NAME} / Manager de transition · Excellence opérationnelle /
      #{SiteIdentity::HOST.delete_prefix('https://')} / #{SiteIdentity::PHONE_DISPLAY}.

      N'écris rien avant le premier marqueur ni après la dernière section.
    PROMPT
  end

  def realisation_links
    RealisationCatalog::ITEMS.map { |item| "#{item[:id]} → #{RealisationCatalog.public_url(item)}" }.join(" · ")
  end

  # Les articles publiés sont les seules pièces publiques qui montrent la compétence sans
  # l'affirmer : la note peut y renvoyer en lecture complémentaire, avec leur adresse.
  def published_articles_block
    articles = Generation.published_on_site.where(kind: :article)
    return "" if articles.empty?

    lines = articles.map { |a| "- #{a.display_title} → #{a.public_url}" }
    <<~BLOCK
      ARTICLES PUBLIÉS PAR CYRILLE (à proposer en lecture complémentaire quand le sujet correspond, sous la
      forme d'un lien markdown [titre de l'article](adresse) — une adresse nue ne devient pas cliquable ;
      jamais pour en recopier le contenu) :
      #{lines.join("\n")}
    BLOCK
  end

  # Format long, pensé pour être trouvé par un moteur et cité par un assistant. Deux
  # contraintes le distinguent de l'actu : il doit répondre à UNE question précise, et
  # chaque affirmation doit pouvoir s'appuyer sur une réalisation réelle du catalogue —
  # un article générique ne sera ni classé ni cité, et exposerait Cyrille en relecture.
  def article_prompt
    <<~PROMPT
      Tu rédiges un article de fond pour le site de Cyrille PIERRE, manager de transition et consultant en
      excellence opérationnelle (20 ans d'industrie, ingénieur Arts & Métiers). Le lecteur est un directeur
      industriel, un directeur de site ou un dirigeant de PME qui cherche une réponse à une question précise,
      souvent depuis un moteur de recherche ou un assistant IA.

      #{ANONYMIZE_COMPANIES_RULE}

      #{ORIENTATION_GUIDANCE.fetch(generation.orientation, ORIENTATION_GUIDANCE['consultant'])}

      RÉALISATIONS DE CYRILLE (la matière de l'article — décrites par secteur et taille, jamais par nom) :
      #{anonymized_realisations_str}

      #{cv_context}

      #{other_articles_block}

      CONSIGNES DE FOND :
      - L'article répond à UNE question, celle du titre, et rien d'autre. Il ne fait pas le tour d'un thème.
      - Écris à la première personne : c'est Cyrille qui parle de ce qu'il a vu et fait, pas un article de
        magazine à la troisième personne.
      - Au moins un cas concret et chiffré, tiré des réalisations ci-dessus, présenté sans nommer
        l'entreprise.
      - Certains résultats sont des résultats de SITE, obtenus par plusieurs chantiers menés de front,
        dont la contribution individuelle n'est pas isolable — c'est d'ailleurs souvent la condition
        pour qu'ils produisent quoi que ce soit. Quand une réalisation le signale, ne présente jamais
        le chiffre comme le rendement d'une initiative seule. Le dire est plus crédible que de
        l'attribuer : un directeur industriel sait qu'un gain de cette ampleur ne vient jamais d'un
        levier unique, et il vous croit davantage si vous le reconnaissez.
      - Un chiffre appartient à la réalisation qui l'a produit, et à elle seule. Ne rattache jamais
        un résultat à un sujet voisin parce que l'histoire serait plus jolie. Lis les lignes
        « ⚠ Périmètre » : elles disent à quels sujets une réalisation ne s'applique PAS. Tu peux
        citer une situation comme signal ou comme contexte sans en revendiquer le résultat chiffré.
      - Tu PEUX mobiliser ce qui se produit couramment dans des situations comparables : les réactions
        typiques d'une équipe, l'ordre dans lequel les objections arrivent, les erreurs que commettent
        la plupart des directions. C'est cette connaissance du terrain qui rend un article utile, et
        Cyrille la possède réellement.
      - Mais la FORME doit dire ce que c'est. Une régularité s'écrit comme une régularité : « le plus
        souvent », « dans la plupart des sites », « ce qui revient presque à chaque fois », « rarement ».
        Un événement précis — daté, situé, chiffré, ou rapporté entre guillemets — est une affirmation
        sur le passé de Cyrille : il ne peut venir QUE des réalisations fournies.
      - Donc : interdit d'inventer un site, une mission, une date, une durée, un chiffre, ou une phrase
        entre guillemets attribuée à quelqu'un. Autorisé, et même souhaitable, de décrire ce qui se
        passe habituellement.
      - Humilité : pas de récit héroïque. Cyrille n'a jamais « sauvé » un site, il a conduit un travail
        avec des équipes — attribue les résultats au collectif quand c'est le cas. Pas de superlatif,
        pas de « j'ai toujours constaté », pas de posture de sachant.
      - Une seule observation générale par section au maximum. Au-delà, l'article cesse d'être un
        retour d'expérience et devient un discours.
      - Dis aussi ce qui ne marche pas, ou ce que la méthode coûte. Un article qui ne concède rien n'est
        pas lu comme une expertise mais comme une publicité.
      - Pas de conclusion creuse ("en conclusion, l'excellence opérationnelle est un levier majeur"). La
        dernière section donne au lecteur quelque chose à faire lundi matin.
      - Aucun appel à l'action commercial dans le corps du texte : la crédibilité fait le travail.

      FORMAT :
      - 800 à 1100 mots. C'est un plafond, pas un objectif : un article plus court qui répond
        mieux vaut toujours mieux qu'un article long qui délaye.
      - 4 à 6 sections AU TOTAL, celle sur les coûts et la section finale comprises. Donc au plus
        quatre sections de fond. Si le sujet comporte plus de points que de sections disponibles,
        regroupe-les — n'ouvre pas une section par point. Dépasser six est un défaut, pas un zèle.
      - Chaque section est introduite par un titre en markdown de niveau 2 (## Titre), qui est une
        affirmation ou une question, jamais un mot seul ("## Méthode").
      - Ordre imposé : le constat, puis la méthode, puis ce que l'approche coûte, puis la dernière
        section qui donne quelque chose à faire. Ne place JAMAIS une section de méthode après celle
        sur les coûts — l'article se lit alors comme s'il repartait après sa fin.
      - Paragraphes courts, 2 à 4 phrases.
      - Le gras (**ainsi**) est réservé à quelques expressions clés, jamais à une phrase entière.
      - Listes à puces avec des tirets, uniquement quand le contenu est réellement une liste.
      - N'écris PAS le titre de l'article : il est saisi à part. Commence directement par le premier
        paragraphe d'introduction, avant la première section.
      - Réponds uniquement avec le texte de l'article, sans commentaire autour.
    PROMPT
  end

  # Un contenu qui renvoie vers les autres sert le lecteur et le référencement : les moteurs
  # comme les assistants lisent ces liens comme le signe d'un ensemble cohérent, pas d'une page
  # isolée. Encore faut-il que le modèle connaisse les adresses — d'où cette liste.
  def other_articles_block
    others = Generation.published_on_site.where.not(id: generation.id).limit(15)
    lines = SITE_PAGES.map { |path, label| "- #{label} → #{path}" }
    lines += others.map do |a|
      suffix = a.article? ? "" : " (brève, à ne citer que si elle apporte vraiment quelque chose)"
      "- #{a.display_title}#{suffix} → #{Rails.application.routes.url_helpers.actu_path(a)}"
    end

    <<~BLOCK
      PAGES DU SITE VERS LESQUELLES TU PEUX RENVOYER :
      #{lines.join("\n")}

      AVANT de rendre ta réponse, relis cette liste et confronte-la à ton texte : chaque fois que tu
      effleures en une phrase un sujet que l'un de ces articles traite en entier, place un lien à cet
      endroit, au format markdown [texte du lien](/actus/12). Deux liens au maximum. Si vraiment aucun
      recoupement n'existe, n'en place aucun — mais cette vérification n'est pas facultative.
      Jamais de liste de liens en fin d'article, jamais de « lire aussi ». Le texte du lien décrit ce
      qu'on y trouve, il ne dit pas « ici » ni « cet article ».
    BLOCK
  end

  def site_actu_prompt
    <<~PROMPT
      Tu rédiges une actualité courte pour le site web de Cyrille PIERRE, consultant indépendant en management
      de transition, excellence opérationnelle et tech/IA.

      #{ANONYMIZE_COMPANIES_RULE}

      #{ORIENTATION_GUIDANCE.fetch(generation.orientation, ORIENTATION_GUIDANCE['consultant'])}

      RÉALISATIONS DE CYRILLE (pour mise en contexte si pertinent, sans citer les identifiants internes type N°XX) :
      #{anonymized_realisations_str}

      #{other_articles_block}

      CONSIGNES :
      - 100 à 200 mots, ton factuel et clair, à la troisième personne
      - Pas de superlatifs publicitaires ("incroyable", "révolutionnaire"…)
      - Ne jamais inventer de chiffres, dates ou faits non présents dans les sources fournies
      - Réponds uniquement avec le texte de l'actu, sans titre ni commentaire autour
    PROMPT
  end
end
