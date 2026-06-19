class Generation < ApplicationRecord
  ALLOWED_FILE_TYPES = %w[text/plain text/markdown application/pdf].freeze
  MAX_FILE_SIZE = 10.megabytes

  belongs_to :user
  has_one_attached :source_file
  has_one_attached :visual

  # Not persisted — a one-off flag from the creation form telling the controller to also
  # generate a visual right after the text (see Studio::GenerationsController#create).
  attr_accessor :generate_visual

  enum :kind, { linkedin_post: 0, cover_letter: 1, site_actu: 2, commercial_proposal: 3 }
  enum :status, { draft: 0, generated: 1, published: 2 }
  enum :orientation, { consultant: 0, transition_management: 1, cdi_search: 2 }, prefix: true

  ORIENTATION_LABELS = {
    "consultant" => "Consultant (missions ponctuelles)",
    "transition_management" => "Manager de transition",
    "cdi_search" => "Recherche de poste en CDI"
  }.freeze

  STRUCTURED_KINDS = %w[cover_letter commercial_proposal].freeze

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

  # value => [label, provider]. :default uses the app's main LLM config (GitHub Models),
  # :mammouth routes through the Mammouth.ai OpenAI-compatible gateway (MAMMOUTH_API_KEY).
  LLM_MODELS = {
    "gpt-4o" => ["GPT-4o", :default],
    "gemini-3.5-flash" => ["Gemini 3.5 Flash (via Mammouth)", :mammouth],
    "claude-sonnet-4-6" => ["Claude Sonnet 4.6 (via Mammouth)", :mammouth],
    "claude-opus-4-8" => ["Claude Opus 4.8 (via Mammouth)", :mammouth],
    "mistral-large-3" => ["Mistral Large 3 (via Mammouth)", :mammouth],
    "gpt-5.4" => ["GPT-5.4 (via Mammouth)", :mammouth]
  }.freeze

  # All routed through Mammouth (image generation isn't available via the app's default
  # provider — see VisualGenerator). gpt-5.4-image-2 is deliberately excluded: it timed out
  # (Cloudflare 524) on every attempt during evaluation.
  IMAGE_MODELS = {
    "gemini-2.5-flash-image" => "Gemini 2.5 Flash",
    "gemini-3.1-flash-image-preview" => "Gemini 3.1 Flash (preview)"
  }.freeze

  validates :kind, presence: true
  validates :llm_model, inclusion: { in: LLM_MODELS.keys }
  validates :image_model, inclusion: { in: IMAGE_MODELS.keys }
  validate :source_file_is_acceptable

  before_save :assign_auto_realisation, if: :linkedin_post?

  def llm_provider
    LLM_MODELS.fetch(llm_model, ["", :default]).last
  end

  scope :published_site_actus, -> { where(kind: :site_actu, status: :published).order(published_at: :desc) }

  def publishable?
    site_actu?
  end

  def structured_output?
    kind.in?(STRUCTURED_KINDS)
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
    return if input_text.present? || input_url.present? || source_file.attached?

    recent_ids = user.generations.where(kind: :linkedin_post).where.not(realisation_id: [nil, ""])
                     .order(created_at: :desc).limit(10).pluck(:realisation_id)
    self.realisation_id = RealisationCatalog.pick_unused(exclude_ids: recent_ids)
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
