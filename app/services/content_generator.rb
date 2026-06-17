# Builds the prompt for a Generation (based on its kind and sources) and calls the LLM.
class ContentGenerator
  MODEL = "gpt-4o-mini"

  def self.call(generation)
    new(generation).call
  end

  def initialize(generation)
    @generation = generation
  end

  def call
    output = RubyLLM.chat(model: MODEL)
                    .with_instructions(system_prompt)
                    .ask(user_prompt)
                    .content.to_s

    generation.update!(output: output, status: :generated)
    generation
  rescue StandardError => e
    Rails.logger.error "ContentGenerator error: #{e.class} — #{e.message}"
    generation.update!(output: "Erreur lors de la génération : #{e.message}", status: :draft)
    generation
  end

  private

  attr_reader :generation

  def system_prompt
    case generation.kind.to_sym
    when :linkedin_post
      linkedin_post_prompt
    when :job_application
      job_application_prompt
    when :site_actu
      site_actu_prompt
    end
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

  def linkedin_post_prompt
    <<~PROMPT
      Tu rédiges des posts LinkedIn pour Cyrille PIERRE, consultant indépendant en management de transition,
      excellence opérationnelle et tech/IA. Ton style : direct, concret, pas de jargon creux, pas d'emoji excessif.

      RÉALISATIONS DE CYRILLE (à citer si pertinent, sans les identifiants internes type N°XX) :
      #{realisations_str}

      CONSIGNES :
      - 150 à 250 mots
      - Une accroche forte en première ligne (les 2 premières lignes décident si on lit la suite)
      - Phrases courtes, retours à la ligne fréquents (format LinkedIn, pas de gros pavés)
      - Termine par une question ouverte ou une invitation à réagir, sans "lien en commentaire" artificiel
      - Pas de hashtags excessifs (3 maximum, à la fin)
      - Ne jamais inventer de chiffres ou de faits non fournis dans les sources
      - Réponds uniquement avec le texte du post, sans titre ni commentaire autour
    PROMPT
  end

  def job_application_prompt
    <<~PROMPT
      Tu rédiges, pour Cyrille PIERRE (consultant indépendant en management de transition, excellence opérationnelle
      et tech/IA, 20 ans d'expérience industrielle, ingénieur Arts & Métiers), soit une lettre de motivation ciblée
      sur une offre d'emploi/mission, soit une proposition commerciale, selon ce qui ressort des sources fournies.

      RÉALISATIONS DE CYRILLE (à mobiliser pour étayer l'argumentaire, sans citer les identifiants internes type N°XX) :
      #{realisations_str}

      CONSIGNES :
      - Identifie d'abord s'il s'agit d'une offre d'emploi/mission (→ lettre de motivation) ou d'un brief client
        (→ proposition commerciale), à partir des sources fournies
      - Adapte le ton : direct et professionnel, sans formules creuses ("passionné par", "force de proposition"…)
      - Relie explicitement 2 à 3 réalisations de Cyrille aux besoins exprimés dans l'offre/le brief
      - Ne jamais inventer de compétences, chiffres ou expériences non présents dans les sources fournies
      - Structure : accroche, 2-3 paragraphes de mise en relation profil/besoin, conclusion avec appel à l'échange
      - Longueur : 250 à 400 mots
      - Réponds uniquement avec le texte final, sans titre ni commentaire autour
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
