class Generation < ApplicationRecord
  ALLOWED_FILE_TYPES = %w[text/plain text/markdown application/pdf].freeze
  MAX_FILE_SIZE = 10.megabytes

  belongs_to :user
  belongs_to :prospect, optional: true
  # Un post LinkedIn peut promouvoir un article publié : c'est ce lien qui permet au prompt
  # d'y renvoyer, et donc au lecteur d'arriver sur une page de fond plutôt que sur un profil.
  belongs_to :source_article, class_name: "Generation", optional: true
  has_one_attached :source_file
  has_one_attached :visual

  # Not persisted — a one-off flag from the creation form telling the controller to also
  # generate a visual right after the text (see Studio::GenerationsController#create).
  attr_accessor :generate_visual

  # `article` : format long qui répond à une question précise, pensé pour être trouvé et cité.
  # `site_actu` reste la brève. Les deux se publient sur /actus.
  # `executive_brief` : la note de diagnostic dirigeant — un diagnostic chiffré tiré des comptes et du
  # terrain, SANS l'ordonnance (voir ContentGenerator::NO_PRESCRIPTION_RULE), pour donner à un PDG ou à
  # un board l'envie d'un entretien. Document privé, jamais publié, rendu imprimable par `document`.
  # `outreach_message` : le premier message à un décideur repéré par la veille — trois lignes qui
  # nomment la source publique du signal et posent une question. Il précède la note de diagnostic.
  enum :kind, { linkedin_post: 0, cover_letter: 1, site_actu: 2, commercial_proposal: 3, article: 4,
                executive_brief: 5, outreach_message: 6 }

  KIND_LABELS = {
    "linkedin_post" => "Post LinkedIn",
    "cover_letter" => "Lettre de motivation",
    "commercial_proposal" => "Proposition commerciale",
    "site_actu" => "Actu du site",
    "article" => "Article de fond",
    "executive_brief" => "Note de diagnostic dirigeant",
    "outreach_message" => "Message de premier contact"
  }.freeze
  enum :status, { draft: 0, generated: 1, published: 2 }
  enum :orientation, { consultant: 0, transition_management: 1, cdi_search: 2 }, prefix: true

  ORIENTATION_LABELS = {
    "consultant" => "Consultant (missions ponctuelles)",
    "transition_management" => "Manager de transition",
    "cdi_search" => "Recherche de poste en CDI"
  }.freeze

  STRUCTURED_KINDS = %w[cover_letter commercial_proposal executive_brief outreach_message].freeze
  # Les contenus dont Ruby relit les chiffres contre les sources (FigureAudit) : ceux qui partent
  # chez un dirigeant sans relecture.
  AUDITED_KINDS = %w[executive_brief outreach_message].freeze
  SENT_VIA = { "linkedin" => "LinkedIn", "email" => "email" }.freeze

  SECTION_MARKERS = {
    final: "###VERSION_FINALE###",
    personalize: "###A_PERSONNALISER###",
    verify: "###A_VERIFIER###",
    short: "###VERSION_COURTE###"
  }.freeze

  SECTION_LABELS = {
    final: "Version finale",
    personalize: "Points à personnaliser",
    verify: "Éléments à vérifier",
    short: "Version courte"
  }.freeze

  # Pour la note de diagnostic, la quatrième section n'est pas un résumé mais la lettre qui
  # accompagne le document : le libellé doit le dire, sinon on l'enverrait comme un condensé. Et la
  # troisième n'est plus une liste à vérifier à la main : c'est le journal de la relecture
  # automatique des chiffres (FigureAudit, dans ContentGenerator).
  EXECUTIVE_BRIEF_SECTION_LABELS = SECTION_LABELS.merge(
    final: "La note (document imprimable)",
    verify: "Corrections automatiques",
    short: "Lettre d'accompagnement"
  ).freeze

  OUTREACH_SECTION_LABELS = SECTION_LABELS.merge(
    final: "Message LinkedIn",
    verify: "Corrections automatiques",
    short: "Variante email (objet en première ligne)"
  ).freeze

  # value => label. All models are served by the Mammouth.ai OpenAI-compatible gateway
  # (MAMMOUTH_API_KEY) — the former GitHub Models free tier expired and was removed.
  LLM_MODELS = {
    "claude-fable-5.1" => "Claude Fable 5.1",
    "claude-opus-4-8" => "Claude Opus 4.8",
    "claude-sonnet-4-6" => "Claude Sonnet 4.6",
    "gemini-3.5-flash" => "Gemini 3.5 Flash",
    "mistral-large-3" => "Mistral Large 3",
    "gpt-5.4" => "GPT-5.4"
  }.freeze

  # Le brouillon part sur le modèle le plus capable (choix de Cyrille, 18/09/2026) : une note de
  # diagnostic ou un article se relisent moins quand ils sortent bons. La relecture orthographique
  # et l'assistant de contact restent sur le modèle rapide de `Mammouth::DEFAULT_MODEL`.
  DEFAULT_LLM_MODEL = "claude-fable-5.1".freeze

  # All routed through Mammouth (image generation isn't available via the app's default
  # provider — see VisualGenerator). gpt-5.4-image-2 is deliberately excluded: it timed out
  # (Cloudflare 524) on every attempt during evaluation.
  # Le premier est le défaut (VisualGenerator et défaut de colonne). Gemini 3 Pro Image est le
  # meilleur des modèles d'image de la passerelle (essai du 18/09/2026 : 15 s, composition propre) ;
  # gpt-image-2 renvoie une page d'erreur Cloudflare, comme gpt-5.4-image-2 avant lui.
  IMAGE_MODELS = {
    "gemini-3-pro-image-preview" => "Gemini 3 Pro Image",
    "gemini-2.5-flash-image" => "Gemini 2.5 Flash",
    "gemini-3.1-flash-image-preview" => "Gemini 3.1 Flash (preview)"
  }.freeze

  validates :kind, presence: true
  validates :llm_model, inclusion: { in: LLM_MODELS.keys }
  validates :image_model, inclusion: { in: IMAGE_MODELS.keys }
  validate :source_file_is_acceptable
  validate :source_article_is_a_published_article

  before_save :assign_auto_realisation, if: :linkedin_post?

  PUBLISHABLE_KINDS = %w[site_actu article].freeze

  scope :published_on_site,
        -> { where(kind: PUBLISHABLE_KINDS, status: :published).order(published_at: :desc) }

  def publishable?
    kind.in?(PUBLISHABLE_KINDS)
  end

  # Titre visible et cliquable dans une liste ou un résultat de recherche : un article sans
  # titre n'a aucune chance d'être cité, autant le signaler par un repli explicite.
  def display_title
    title.presence || default_title
  end

  def default_title
    return "Article sans titre" if article?
    return "Note de diagnostic" if executive_brief?
    return "Premier contact" if outreach_message?

    "Actualité"
  end

  # Libellé de la pastille sur /actus. Une pastille sur les seuls articles laissait croire que
  # les autres entrées n'étaient pas classées : le lecteur doit savoir dans les deux cas s'il
  # ouvre trois lignes ou mille mots.
  def kind_label
    article? ? "Article" : "Actu"
  end

  # Libellé du type dans le Studio, en français ; `kind.humanize` donnait « Executive brief ».
  def kind_name
    KIND_LABELS.fetch(kind, kind.humanize)
  end

  def section_labels
    return EXECUTIVE_BRIEF_SECTION_LABELS if executive_brief?
    return OUTREACH_SECTION_LABELS if outreach_message?

    SECTION_LABELS
  end

  def audited?
    kind.in?(AUDITED_KINDS)
  end

  # La variante email tient dans la quatrième section : « Objet : … » sur la première ligne, le
  # corps ensuite. Sans objet lisible, le message part avec un objet de repli plutôt que vide.
  def email_subject
    line = sections[:short].to_s.lines.first.to_s.strip
    subject = line[/\A\s*objet\s*:\s*(.+)\z/i, 1]
    subject.presence || "Prise de contact — #{prospect&.display_company}"
  end

  def email_body
    lines = sections[:short].to_s.lines
    lines.shift if lines.first.to_s.match?(/\A\s*objet\s*:/i)
    lines.join.strip
  end

  def email_sendable?
    outreach_message? && generated? && output.present? && prospect&.email.present?
  end

  def sent?
    sent_at.present?
  end

  # Le message est parti : la génération le retient, et la fiche prospect devient le journal du
  # contact (date, canal, relance dans une semaine).
  def mark_sent!(via)
    transaction do
      update!(sent_at: Time.current, sent_via: via)
      prospect&.log_first_contact!(via: SENT_VIA.fetch(via, via), generation: self)
    end
  end

  def excerpt(length: 220)
    ArticleFormatter.plain_text(output).truncate(length)
  end

  # Vrai tant que la tâche de fond n'a pas rendu la main. Au-delà de ce délai on considère
  # qu'elle a échoué : sans cette borne, une page resterait en attente indéfiniment. Quinze
  # minutes, pas cinq : une note de diagnostic sur Fable 5.1 avec sa passe de correction a pris
  # 8 min 28 s le 18/09/2026, et la page annonçait un échec alors que la tâche finissait.
  GENERATION_TIMEOUT = 15.minutes

  def generating?
    generating_since.present? && generating_since > GENERATION_TIMEOUT.ago
  end

  def generation_stalled?
    generating_since.present? && generating_since <= GENERATION_TIMEOUT.ago
  end

  def structured_output?
    kind.in?(STRUCTURED_KINDS)
  end

  # Adresse publique de la page, pour qu'un post LinkedIn puisse y renvoyer.
  def public_url
    "#{StructuredData::HOST}#{Rails.application.routes.url_helpers.actu_path(self)}"
  end

  # La réalisation imposée à un post sans source, par rotation (assign_auto_realisation) ou
  # choix manuel dans le formulaire. Les deux générateurs, texte et visuel, la lisent ici.
  def locked_realisation
    RealisationCatalog.find(realisation_id) if realisation_id.present?
  end

  def linkedin_post_url
    return if linkedin_post_urn.blank?

    "https://www.linkedin.com/feed/update/#{linkedin_post_urn}/"
  end

  # Splits the LLM output into labelled sections when the prompt asked for the
  # ###MARKER### format (cover letters, commercial proposals). Falls back to a
  # single "final" section if the markers are missing (e.g. generation failed).
  def sections
    return { final: output.to_s } unless structured_output?

    marker_to_key = SECTION_MARKERS.invert
    parts = output.to_s.split(Regexp.union(SECTION_MARKERS.values)).map(&:strip)
    markers_found = output.to_s.scan(Regexp.union(SECTION_MARKERS.values))

    result = {}
    markers_found.each_with_index do |marker, index|
      content = parts[index + 1]
      result[marker_to_key[marker]] = content if content.present?
    end

    result.presence || { final: output.to_s }
  end

  private

  # When a LinkedIn post has no source to work from, the model would otherwise invent
  # both the topic and the realisation to cite — pick one upfront instead, so the prompt
  # can frame the post around it (see ContentGenerator#linkedin_post_prompt).
  def assign_auto_realisation
    return if realisation_id.present?
    # Un post tiré d'un article a déjà son sujet : lui imposer une réalisation par rotation le
    # ferait parler d'autre chose que de l'article qu'il est censé faire lire.
    return if source_article_id.present?
    return if input_text.present? || input_url.present? || source_file.attached?

    recent_ids = user.generations.where(kind: :linkedin_post).where.not(realisation_id: [nil, ""])
                     .order(created_at: :desc).limit(10).pluck(:realisation_id)
    self.realisation_id = RealisationCatalog.pick_unused(exclude_ids: recent_ids)
  end

  def source_article_is_a_published_article
    return if source_article.blank?

    errors.add(:source_article, "doit être un article publié") unless source_article.article? &&
                                                                      source_article.published?
  end

  def source_file_is_acceptable
    return unless source_file.attached?

    unless source_file.content_type.in?(ALLOWED_FILE_TYPES)
      errors.add(:source_file, "doit être un fichier texte, markdown ou PDF")
    end

    return unless source_file.byte_size > MAX_FILE_SIZE

    errors.add(:source_file, "doit faire moins de 10 Mo")
  end
end
