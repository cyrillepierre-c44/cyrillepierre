require "test_helper"

class VisualGeneratorTest < ActiveSupport::TestCase
  FakeImage = Struct.new(:to_blob, :mime_type)

  # Enregistre les arguments reçus par `paint` pour pouvoir vérifier le prompt construit.
  class FakePainter
    attr_reader :prompt, :options

    def initialize(image: FakeImage.new("fake-png-bytes", "image/png"), error: nil)
      @image = image
      @error = error
    end

    def paint(prompt, **options)
      @prompt = prompt
      @options = options
      raise @error if @error

      @image
    end
  end

  # RubyLLM.context reçoit un bloc de configuration : on le laisse s'exécuter sur un double,
  # sinon les lignes qui posent la clé et l'URL de Mammouth ne seraient jamais jouées.
  ConfigDouble = Struct.new(:openai_api_key, :openai_api_base)

  setup do
    @user = User.create!(email: "visual-#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  def generation(**attrs)
    Generation.create!(user: @user, kind: :linkedin_post, output: "Un post sur la performance.", **attrs)
  end

  def with_painter(painter)
    config = ConfigDouble.new
    RubyLLM.stub(:context, painter, config) { yield config }
  end

  test "attaches the generated image to the generation" do
    record = generation
    painter = FakePainter.new

    with_painter(painter) { VisualGenerator.call(record) }

    assert record.reload.visual.attached?
    assert_equal "image/png", record.visual.content_type
    assert_equal "visual.png", record.visual.filename.to_s
  end

  test "configures the Mammouth gateway rather than the default OpenAI one" do
    config = nil
    with_painter(FakePainter.new) { |c| VisualGenerator.call(generation); config = c }

    assert_equal VisualGenerator::MAMMOUTH_API_BASE, config.openai_api_base
  end

  test "uses the image model chosen on the generation" do
    model = Generation::IMAGE_MODELS.keys.last
    painter = FakePainter.new

    with_painter(painter) { VisualGenerator.call(generation(image_model: model)) }

    assert_equal model, painter.options[:model]
  end

  test "the prompt carries the style rules and the post itself" do
    painter = FakePainter.new

    with_painter(painter) { VisualGenerator.call(generation(output: "Un post sur les horaires d'équipe.")) }

    assert_includes painter.prompt, VisualGenerator::STYLE_PROMPT.strip
    assert_includes painter.prompt, "Un post sur les horaires d'équipe."
  end

  # Réalisation verrouillée : le visuel doit s'inspirer de l'illustration existante du site,
  # d'où l'ajout du texte de la réalisation et de son visual_hint au prompt.
  test "a locked realisation adds its facts and its visual hint to the prompt" do
    item = RealisationCatalog::ITEMS.find { |i| i[:visual_hint].present? }
    painter = FakePainter.new

    with_painter(painter) { VisualGenerator.call(generation(realisation_id: item[:id])) }

    assert_includes painter.prompt, item[:titre]
    assert_includes painter.prompt, item[:visual_hint]
    assert_includes painter.prompt, item[:resultat]
  end

  # Dès qu'un brief est fourni, `assign_auto_realisation` ne verrouille plus de réalisation :
  # le modèle a choisi son angle librement, le visuel garde la même liberté.
  test "without a locked realisation the prompt stays free of catalogue constraints" do
    painter = FakePainter.new
    record = generation(input_text: "Parler de la refonte du planning d'équipe.")
    assert_nil record.realisation_id, "aucune réalisation ne doit être verrouillée avec un brief"

    with_painter(painter) { VisualGenerator.call(record) }

    assert_not_includes painter.prompt, "Réalisation précise à illustrer"
    assert_not_includes painter.prompt, "Inspiration pour la composition"
  end

  # Le catalogue impose un visual_hint pour chaque réalisation (toute nouvelle entrée doit
  # arriver avec son illustration SVG et son hint). Ce test couvre le repli si la règle venait
  # à être enfreinte : on garde les faits, on perd seulement l'inspiration de design.
  test "a realisation without a visual hint still contributes its facts" do
    item = RealisationCatalog::ITEMS.first.merge(visual_hint: nil)
    painter = FakePainter.new

    RealisationCatalog.stub(:find, item) do
      with_painter(painter) { VisualGenerator.call(generation(realisation_id: item[:id])) }
    end

    assert_includes painter.prompt, item[:titre]
    assert_not_includes painter.prompt, "Inspiration pour la composition"
  end

  # Une panne de génération d'image ne doit jamais faire échouer la création du contenu :
  # le texte est déjà écrit, seul le visuel manque.
  test "swallows a painting failure and returns the generation untouched" do
    record = generation
    painter = FakePainter.new(error: RuntimeError.new("timeout Cloudflare"))

    result = with_painter(painter) { VisualGenerator.call(record) }

    assert_equal record, result
    assert_not record.reload.visual.attached?
  end
end
