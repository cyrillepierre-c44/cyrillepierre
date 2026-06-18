class Generation < ApplicationRecord
  ALLOWED_FILE_TYPES = %w[text/plain text/markdown application/pdf].freeze
  MAX_FILE_SIZE = 10.megabytes

  belongs_to :user
  has_one_attached :source_file

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
    "gemini-3.5-flash" => ["Gemini 3.5 Flash (via Mammouth)", :mammouth]
  }.freeze

  validates :kind, presence: true
  validates :llm_model, inclusion: { in: LLM_MODELS.keys }
  validate :source_file_is_acceptable

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

  def source_file_is_acceptable
    return unless source_file.attached?

    unless source_file.content_type.in?(ALLOWED_FILE_TYPES)
      errors.add(:source_file, "doit être un fichier texte, markdown ou PDF")
    end

    return unless source_file.byte_size > MAX_FILE_SIZE

    errors.add(:source_file, "doit faire moins de 10 Mo")
  end
end
