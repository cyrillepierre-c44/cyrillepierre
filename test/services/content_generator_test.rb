require "test_helper"

class ContentGeneratorTest < ActiveSupport::TestCase
  Reply = Struct.new(:content)

  # Capture les instructions et la question envoyées au modèle, pour pouvoir inspecter le
  # prompt construit sans jamais sortir sur le réseau.
  class FakeChat
    attr_reader :model, :instructions, :question

    def initialize(model, replies, error)
      @model = model
      @replies = replies
      @error = error
    end

    def with_instructions(text)
      @instructions = text
      self
    end

    def ask(question)
      @question = question
      raise @error if @error

      Reply.new(@replies.shift || "")
    end
  end

  class FakeContext
    attr_reader :chats

    def initialize(replies: [], error: nil, proofread_error: nil)
      @replies = replies
      @error = error
      @proofread_error = proofread_error
      @chats = []
    end

    def chat(model:, **)
      proofreading = model == ContentGenerator::PROOFREADING_MODEL && @chats.any?
      chat = FakeChat.new(model, @replies, proofreading ? @proofread_error : @error)
      @chats << chat
      chat
    end

    def draft_chat = chats.first
    def proofreading_chat = chats.last
  end

  setup do
    @user = User.create!(email: "gen-#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  def generation(**attrs)
    Generation.create!(user: @user, kind: :linkedin_post, **attrs)
  end

  def run_generator(record, context)
    RubyLLM.stub(:context, context, Struct.new(:openai_api_key, :openai_api_base).new) do
      ContentGenerator.call(record)
    end
    context
  end

  # --- le cycle nominal ------------------------------------------------------

  test "stores the proofread text and marks the generation as generated" do
    record = generation
    context = FakeContext.new(replies: [ "Brouillon avec una faute.", "Brouillon avec une faute." ])

    run_generator(record, context)

    assert_equal "Brouillon avec une faute.", record.reload.output
    assert record.generated?
  end

  test "drafts with the model chosen on the generation" do
    record = generation(llm_model: Generation::LLM_MODELS.keys.last)
    context = FakeContext.new(replies: [ "brouillon", "relu" ])

    run_generator(record, context)

    assert_equal record.llm_model, context.draft_chat.model
  end

  # La relecture tourne toujours sur le modèle rapide, quel que soit le modèle du brouillon.
  test "proofreads on the dedicated fast model whatever the draft model is" do
    record = generation(llm_model: Generation::LLM_MODELS.keys.last)
    context = FakeContext.new(replies: [ "brouillon", "relu" ])

    run_generator(record, context)

    assert_equal ContentGenerator::PROOFREADING_MODEL, context.proofreading_chat.model
    assert_equal ContentGenerator::PROOFREADING_INSTRUCTIONS, context.proofreading_chat.instructions
  end

  # --- les chemins de panne --------------------------------------------------

  test "records the error in the output and falls back to draft status" do
    record = generation
    context = FakeContext.new(error: RuntimeError.new("passerelle indisponible"))

    run_generator(record, context)

    assert_includes record.reload.output, "Erreur lors de la génération"
    assert_includes record.output, "passerelle indisponible"
    assert record.draft?
  end

  # Une panne de relecture ne doit pas perdre le brouillon déjà produit.
  test "keeps the raw draft when proofreading fails" do
    record = generation
    context = FakeContext.new(replies: [ "Le brouillon utile." ],
                              proofread_error: RuntimeError.new("timeout"))

    run_generator(record, context)

    assert_equal "Le brouillon utile.", record.reload.output
    assert record.generated?
  end

  test "does not call the proofreader on an empty draft" do
    record = generation
    context = FakeContext.new(replies: [ "" ])

    run_generator(record, context)

    assert_equal 1, context.chats.size
  end

  # --- construction du prompt utilisateur ------------------------------------

  test "falls back to a generic instruction when no source is given" do
    context = FakeContext.new(replies: [ "a", "b" ])

    run_generator(generation, context)

    assert_includes context.draft_chat.question, "Aucune source fournie"
  end

  test "passes the pasted text, the extra instructions and the attached file" do
    record = generation(input_text: "Notes de réunion.", extra_instructions: "Ton plus direct.")
    record.source_file.attach(io: StringIO.new("Contenu du fichier joint."), filename: "notes.txt",
                              content_type: "text/plain")
    context = FakeContext.new(replies: [ "a", "b" ])

    run_generator(record, context)

    question = context.draft_chat.question
    assert_includes question, "Notes de réunion."
    assert_includes question, "Contenu du fichier joint."
    assert_includes question, "Ton plus direct."
  end

  test "includes the scraped content of the provided URL" do
    record = generation(input_url: "https://example.com/article")
    context = FakeContext.new(replies: [ "a", "b" ])

    UrlScraper.stub(:call, "Le contenu de la page.") { run_generator(record, context) }

    assert_includes context.draft_chat.question, "Le contenu de la page."
  end

  # Une URL injoignable ne doit pas faire échouer toute la génération.
  test "reports an unreachable URL inside the prompt instead of raising" do
    record = generation(input_url: "https://example.com/article")
    context = FakeContext.new(replies: [ "a", "b" ])

    raiser = ->(_url) { raise UrlScraper::UnsafeUrlError, "Adresse IP non autorisée" }
    UrlScraper.stub(:call, raiser) { run_generator(record, context) }

    assert_includes context.draft_chat.question, "impossible de récupérer cette URL"
    assert_includes context.draft_chat.question, "Adresse IP non autorisée"
  end

  # --- prompts système par type de contenu -----------------------------------

  test "every kind builds its own system prompt on top of the writing rules" do
    Generation.kinds.each_key do |kind|
      record = Generation.create!(user: @user, kind: kind)
      context = FakeContext.new(replies: [ "a", "b" ])

      run_generator(record, context)

      assert_includes context.draft_chat.instructions, "RÈGLES D'ÉCRITURE",
                      "les règles d'écriture manquent pour #{kind}"
    end
  end

  test "the structured kinds ask for the four marked sections" do
    Generation::STRUCTURED_KINDS.each do |kind|
      record = Generation.create!(user: @user, kind: kind)
      context = FakeContext.new(replies: [ "a", "b" ])

      run_generator(record, context)

      Generation::SECTION_MARKERS.each_value do |marker|
        assert_includes context.draft_chat.instructions, marker, "marqueur #{marker} absent pour #{kind}"
      end
    end
  end

  # --- anonymisation ---------------------------------------------------------

  # Les contenus publics ne doivent jamais nommer une entreprise ; les contenus privés
  # (lettre, proposition) gardent les vrais noms, c'est ce qui fait leur crédibilité.
  test "public kinds carry the anonymisation rule and private ones do not" do
    %w[linkedin_post site_actu article].each do |kind|
      context = FakeContext.new(replies: [ "a", "b" ])
      run_generator(Generation.create!(user: @user, kind: kind), context)

      assert_includes context.draft_chat.instructions, "CONFIDENTIALITÉ — RÈGLE ABSOLUE",
                      "#{kind} devrait être anonymisé"
    end

    %w[cover_letter commercial_proposal].each do |kind|
      context = FakeContext.new(replies: [ "a", "b" ])
      run_generator(Generation.create!(user: @user, kind: kind), context)

      assert_not_includes context.draft_chat.instructions, "CONFIDENTIALITÉ — RÈGLE ABSOLUE",
                          "#{kind} ne devrait pas être anonymisé"
    end
  end

  # --- réalisation verrouillée ----------------------------------------------

  test "a locked realisation becomes the mandatory frame of the post" do
    item = RealisationCatalog::ITEMS.first
    record = generation(realisation_id: item[:id])
    context = FakeContext.new(replies: [ "a", "b" ])

    run_generator(record, context)

    instructions = context.draft_chat.instructions
    assert_includes instructions, "RÉALISATION À UTILISER POUR CE POST"
    assert_includes instructions, item[:titre]
  end

  test "a brief leaves the full catalogue available to the model" do
    record = generation(input_text: "Parler du planning d'équipe.")
    context = FakeContext.new(replies: [ "a", "b" ])
    assert_nil record.realisation_id

    run_generator(record, context)

    assert_includes context.draft_chat.instructions, "RÉALISATIONS DE CYRILLE"
    assert_not_includes context.draft_chat.instructions, "RÉALISATION À UTILISER POUR CE POST"
  end

  # --- orientation et posts récents -----------------------------------------

  test "the orientation steers the tone and the call to action" do
    record = generation(orientation: :transition_management)
    context = FakeContext.new(replies: [ "a", "b" ])

    run_generator(record, context)

    assert_includes context.draft_chat.instructions,
                    ContentGenerator::ORIENTATION_GUIDANCE["transition_management"].strip
  end

  test "recent posts are listed so the model does not repeat itself" do
    Generation.create!(user: @user, kind: :linkedin_post, status: :generated,
                       output: "Un post déjà publié sur les UAP.")
    context = FakeContext.new(replies: [ "a", "b" ])

    run_generator(generation, context)

    assert_includes context.draft_chat.instructions, "POSTS LINKEDIN RÉCENTS"
    assert_includes context.draft_chat.instructions, "Un post déjà publié sur les UAP."
  end

  test "says so explicitly when there is no recent post to avoid" do
    context = FakeContext.new(replies: [ "a", "b" ])

    run_generator(generation, context)

    assert_includes context.draft_chat.instructions, "Aucun post LinkedIn récent"
  end

  # --- contexte CV -----------------------------------------------------------

  test "the CV text is injected into the prompt" do
    context = FakeContext.new(replies: [ "a", "b" ])

    run_generator(Generation.create!(user: @user, kind: :cover_letter), context)

    assert_includes context.draft_chat.instructions, "CV COMPLET DE CYRILLE"
  end

  # Le rendu du CV ne doit jamais faire tomber une génération : on perd le contexte, pas le post.
  test "a failing CV render degrades to an empty context instead of raising" do
    context = FakeContext.new(replies: [ "a", "b" ])
    raiser = -> { raise "template introuvable" }

    CvText.stub(:call, raiser) do
      run_generator(Generation.create!(user: @user, kind: :cover_letter), context)
    end

    assert_not_includes context.draft_chat.instructions, "CV COMPLET DE CYRILLE"
  end
  # --- article de fond -------------------------------------------------------

  # Le format long n'a d'intérêt que s'il répond à une question et s'appuie sur du réel :
  # un article générique ne serait ni classé ni cité, et exposerait Cyrille en relecture.
  test "the article prompt asks for a long, sourced, first-person answer" do
    context = FakeContext.new(replies: [ "a", "b" ])
    run_generator(Generation.create!(user: @user, kind: :article), context)

    instructions = context.draft_chat.instructions
    assert_includes instructions, "800 à 1200 mots"
    assert_includes instructions, "répond à UNE question"
    assert_includes instructions, "première personne"
    assert_includes instructions, "Ne jamais inventer"
    assert_includes instructions, "## Titre"
  end

  test "the article prompt carries the catalogue it must draw from" do
    context = FakeContext.new(replies: [ "a", "b" ])
    run_generator(Generation.create!(user: @user, kind: :article), context)

    assert_includes context.draft_chat.instructions, RealisationCatalog::ITEMS.first[:titre]
  end
end
