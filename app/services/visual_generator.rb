# Generates an illustration to accompany a LinkedIn post, via the same Mammouth gateway
# already used for text generation in ContentGenerator.
class VisualGenerator
  MAMMOUTH_API_BASE = "https://api.mammouth.ai/v1"

  STYLE_PROMPT = <<~TXT
    Flat minimalist line-art illustration, dark navy (#1a2332) background, gold (#c9a961) lines only.
    Pick concrete visual elements that genuinely match the SPECIFIC subject described below — read it
    carefully first. Examples of how the scene should adapt: a production line/conveyor/machinery for a
    post about machines or production performance; a planning board, calendar grid or roster for a post
    about staffing, shifts or working hours; an org chart, meeting table or HR-style folder/badge icons
    for a post about people management, negotiation or training; a supply chain/truck/warehouse scene for
    logistics. Never default to factory machinery if the subject is actually about people, schedules or
    organisation — never a generic abstract tech/network/globe illustration either.
    Include a concrete visual metaphor for a measurable improvement tied to the result described below:
    a screen or dashboard showing a bar chart where one bar is clearly cut in half versus the other, or a
    gauge needle moving from a red zone to a green zone. This gauge/chart may use red, yellow and green
    accents — every other element of the illustration stays navy/gold only.
    No text, no readable letters or numbers. People, if shown at all, must be simple faceless
    silhouettes or icons (no eyes, no nose, no mouth, no facial features, no head profile outline) —
    like a generic pictogram, never a recognisable human face or profile.
  TXT

  def self.call(generation)
    new(generation).call
  end

  def initialize(generation)
    @generation = generation
  end

  def call
    image = mammouth_context.paint(prompt, model: image_model, provider: :openai, assume_model_exists: true)
    generation.visual.attach(io: StringIO.new(image.to_blob), filename: "visual.png", content_type: image.mime_type)
    generation
  rescue StandardError => e
    Rails.logger.error "VisualGenerator error: #{e.class} — #{e.message}"
    generation
  end

  private

  attr_reader :generation

  def image_model
    generation.image_model.presence || Generation::IMAGE_MODELS.keys.first
  end

  def mammouth_context
    RubyLLM.context do |c|
      c.openai_api_key = ENV.fetch("MAMMOUTH_API_KEY", nil)
      c.openai_api_base = MAMMOUTH_API_BASE
    end
  end

  # The generated post itself is the primary indication of what to depict — it carries the
  # actual angle/narrative the LLM chose, which the bare catalogue facts don't (especially when
  # a brief steered the post toward a specific framing). The locked realisation's type_orga and
  # resultat (when there is one) are added on top to anchor the scene in a real industrial
  # setting and the exact figures, instead of letting the image model improvise or invent numbers.
  def prompt
    parts = [STYLE_PROMPT, "Post LinkedIn à illustrer :\n#{generation.output}"]
    parts << "Faits précis à respecter pour la scène : #{locked_realisation_facts}" if locked_realisation_facts
    parts.join("\n\n")
  end

  def locked_realisation_facts
    return unless generation.realisation_id.present?

    r = RealisationCatalog.find(generation.realisation_id)
    return unless r

    "#{r[:type_orga]} — résultat mesuré : #{r[:resultat]}"
  end
end
