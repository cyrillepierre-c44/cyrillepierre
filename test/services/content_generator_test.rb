require "test_helper"

class ContentGeneratorTest < ActiveSupport::TestCase
  Reply = Struct.new(:content)

  # Capture les instructions et la question envoyées au modèle, pour pouvoir inspecter le
  # prompt construit sans jamais sortir sur le réseau.
  class FakeChat
    attr_reader :model, :instructions, :question, :streamed

    def initialize(model, replies, error)
      @model = model
      @replies = replies
      @error = error
    end

    def with_instructions(text)
      @instructions = text
      self
    end

    # `:echo` renvoie la question telle quelle : c'est ce que fait une relecture sans faute.
    def ask(question, &block)
      @question = question
      @streamed = block_given?
      raise @error if @error

      reply = @replies.shift
      Reply.new(reply == :echo ? question : reply || "")
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

  # Cloudflare coupe une requête muette au bout de 100 s devant la passerelle Mammouth : chaque
  # appel passe en flux, sinon un modèle qui réfléchit longtemps meurt avant son premier mot.
  test "every call to the model streams, draft and proofreading alike" do
    context = FakeContext.new(replies: [ "a", "b" ])

    run_generator(generation, context)

    assert context.chats.all?(&:streamed), "un appel sans flux"
  end

  test "a gateway error page is summarised to its title" do
    html = "<html><head><title>mammouth.ai | 524: A timeout occurred</title></head><body>long</body></html>"
    record = generation

    run_generator(record, FakeContext.new(error: RuntimeError.new(html)))

    assert_equal "Erreur lors de la génération : passerelle Mammouth — mammouth.ai | 524: A timeout occurred",
                 record.reload.output
    assert record.draft?
  end

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

  # La note de diagnostic ne demande pas la section « à vérifier » au modèle : Ruby l'écrit
  # lui-même à partir de la relecture automatique des chiffres.
  test "the structured kinds ask for the marked sections" do
    Generation::STRUCTURED_KINDS.each do |kind|
      record = Generation.create!(user: @user, kind: kind)
      context = FakeContext.new(replies: [ "a", "b" ])

      run_generator(record, context)

      Generation::SECTION_MARKERS.each do |key, marker|
        next if key == :verify && kind == "executive_brief"

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

    %w[cover_letter commercial_proposal executive_brief].each do |kind|
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
    assert_includes instructions, "800 à 1100 mots"
    assert_includes instructions, "répond à UNE question"
    assert_includes instructions, "première personne"
    assert_includes instructions, "## Titre"
  end

  # Cyrille relit tout avant publication, donc la créativité du modèle n'est pas bridée :
  # ce qui est interdit, c'est de faire passer une régularité du métier pour un souvenir daté.
  test "the article prompt allows general observations but forbids invented specifics" do
    context = FakeContext.new(replies: [ "a", "b" ])
    run_generator(Generation.create!(user: @user, kind: :article), context)

    instructions = context.draft_chat.instructions
    assert_includes instructions, "Tu PEUX mobiliser ce qui se produit couramment"
    assert_includes instructions, "Une régularité s'écrit comme une régularité"
    assert_includes instructions, "interdit d'inventer un site, une mission, une date"
    assert_includes instructions, "entre guillemets attribuée à quelqu'un"
    assert_includes instructions, "pas de récit héroïque"
  end

  test "the article prompt fixes the order of the sections" do
    context = FakeContext.new(replies: [ "a", "b" ])
    run_generator(Generation.create!(user: @user, kind: :article), context)

    assert_includes context.draft_chat.instructions, "Ordre imposé"
    assert_includes context.draft_chat.instructions, "JAMAIS une section de méthode après celle"
  end

  test "the article prompt carries the catalogue it must draw from" do
    context = FakeContext.new(replies: [ "a", "b" ])
    run_generator(Generation.create!(user: @user, kind: :article), context)

    assert_includes context.draft_chat.instructions, RealisationCatalog::ITEMS.first[:titre]
  end
  # Sans la liste des adresses, le modèle ne peut pas créer de lien interne : il ne connaît
  # pas les URL du site.
  test "the article prompt hands over the published articles it may link to" do
    published = Generation.create!(user: @user, kind: :article, status: :published,
                                   published_at: Time.current, title: "Passer en 3x8",
                                   output: "Du texte.")
    context = FakeContext.new(replies: [ "a", "b" ])
    run_generator(Generation.create!(user: @user, kind: :article), context)

    instructions = context.draft_chat.instructions
    assert_includes instructions, "PAGES DU SITE VERS LESQUELLES TU PEUX RENVOYER"
    assert_includes instructions, "Passer en 3x8 → /actus/#{published.id}"
    assert_includes instructions, "Deux liens au maximum"
  end

  test "a content never offers a link to itself" do
    record = Generation.create!(user: @user, kind: :article, status: :published,
                                published_at: Time.current, title: "Lui-même", output: "Du texte.")
    context = FakeContext.new(replies: [ "a", "b" ])

    run_generator(record, context)

    # Le prompt contient un exemple de lien « /actus/12 » : on vise la ligne de la liste, pas le texte.
    assert_not_includes context.draft_chat.instructions, "→ /actus/#{record.id}"
  end

  # Les pages de fond sont les cibles les plus stables : elles restent offertes même quand rien
  # n'est encore publié, alors que l'adresse d'un article peut disparaître à la dépublication.
  test "the site pages are always offered, even before anything is published" do
    context = FakeContext.new(replies: [ "a", "b" ])
    run_generator(Generation.create!(user: @user, kind: :article), context)

    instructions = context.draft_chat.instructions
    ContentGenerator::SITE_PAGES.each_key do |path|
      assert_includes instructions, "→ #{path}"
    end
  end

  # Une brève mérite le même maillage qu'un article : c'est aussi une page qui doit mener ailleurs.
  test "the short news prompt also gets the link targets" do
    context = FakeContext.new(replies: [ "a", "b" ])
    run_generator(Generation.create!(user: @user, kind: :site_actu), context)

    assert_includes context.draft_chat.instructions, "PAGES DU SITE VERS LESQUELLES TU PEUX RENVOYER"
    assert_includes context.draft_chat.instructions, "→ /realisations"
  end

  test "a short news is offered as a target but flagged as such" do
    Generation.create!(user: @user, kind: :site_actu, status: :published,
                       published_at: Time.current, title: "Une brève", output: "Court.")
    context = FakeContext.new(replies: [ "a", "b" ])

    run_generator(Generation.create!(user: @user, kind: :article), context)

    assert_includes context.draft_chat.instructions, "(brève, à ne citer que si elle apporte"
  end
  # Le catalogue dit, pour certaines réalisations, à quels sujets elles ne s'appliquent PAS.
  # Le Studio ne l'a jamais reçu jusqu'ici : un article rattachait alors un chiffre au mauvais sujet.
  test "the prompts carry the semantic scope of the catalogue" do
    scoped = RealisationCatalog::ITEMS.find { |r| r[:semantic_scope].present? }
    context = FakeContext.new(replies: [ "a", "b" ])

    run_generator(Generation.create!(user: @user, kind: :article), context)

    assert_includes context.draft_chat.instructions, "⚠ Périmètre : #{scoped[:semantic_scope]}"
  end

  test "the private kinds carry the semantic scope too" do
    scoped = RealisationCatalog::ITEMS.find { |r| r[:semantic_scope].present? }
    context = FakeContext.new(replies: [ "a", "b" ])

    run_generator(Generation.create!(user: @user, kind: :commercial_proposal), context)

    assert_includes context.draft_chat.instructions, "⚠ Périmètre : #{scoped[:semantic_scope]}"
  end

  test "the article prompt caps the sections and counts the mandatory ones" do
    context = FakeContext.new(replies: [ "a", "b" ])
    run_generator(Generation.create!(user: @user, kind: :article), context)

    instructions = context.draft_chat.instructions
    assert_includes instructions, "4 à 6 sections AU TOTAL"
    assert_includes instructions, "quatre sections de fond"
    assert_includes instructions, "au plus"
    assert_includes instructions, "Un chiffre appartient à la réalisation qui l'a produit"
  end

  test "checking the other articles for a link is not optional" do
    Generation.create!(user: @user, kind: :article, status: :published, published_at: Time.current,
                       title: "Passer en 3x8", output: "Du texte.")
    context = FakeContext.new(replies: [ "a", "b" ])

    run_generator(Generation.create!(user: @user, kind: :article), context)

    assert_includes context.draft_chat.instructions, "cette vérification n'est pas facultative"
  end
  # Huit points de TRS ne viennent jamais d'un levier unique. Présenter ce chiffre comme le
  # rendement d'une seule initiative exposerait Cyrille à la première question d'un directeur
  # industriel, qui sait que c'est impossible.
  test "the prompt refuses to credit one lever for a whole-site result" do
    context = FakeContext.new(replies: [ "a", "b" ])
    run_generator(Generation.create!(user: @user, kind: :article), context)

    instructions = context.draft_chat.instructions
    assert_includes instructions, "résultats de SITE"
    assert_includes instructions, "contribution individuelle n'est pas isolable"
    assert_includes instructions, "n'est PAS attribuable à la seule fusion des silos"
  end
  # --- post LinkedIn qui promeut un article ---------------------------------

  # Les consignes générales interdisent de pousser un lien, délibérément. Ce cas les lève, et
  # c'est la seule situation où un post doit se terminer par une adresse.
  test "a post promoting an article is told to end on its link" do
    article = Generation.create!(user: @user, kind: :article, status: :published,
                                 published_at: Time.current, title: "Passer en 3x8",
                                 output: "## Une section\n\nUne idée contre-intuitive.")
    context = FakeContext.new(replies: [ "a", "b" ])

    run_generator(Generation.create!(user: @user, kind: :linkedin_post, source_article: article), context)

    instructions = context.draft_chat.instructions
    assert_includes instructions, "CE POST PROMEUT UN ARTICLE DU SITE"
    assert_includes instructions, "ces consignes l'emportent sur celles qui interdisent"
    assert_includes instructions, "https://www.cyrillepierre.com/actus/#{article.id}"
    assert_includes instructions, "Passer en 3x8"
  end

  test "the article text is handed over without its markdown" do
    article = Generation.create!(user: @user, kind: :article, status: :published,
                                 published_at: Time.current, title: "Un titre",
                                 output: "## Une section\n\nUn texte **en gras**.")
    context = FakeContext.new(replies: [ "a", "b" ])

    run_generator(Generation.create!(user: @user, kind: :linkedin_post, source_article: article), context)

    instructions = context.draft_chat.instructions
    assert_includes instructions, "Une section Un texte en gras."
    assert_not_includes instructions, "## Une section"
  end

  test "an ordinary post is never told to push a link" do
    context = FakeContext.new(replies: [ "a", "b" ])

    run_generator(Generation.create!(user: @user, kind: :linkedin_post), context)

    assert_not_includes context.draft_chat.instructions, "CE POST PROMEUT UN ARTICLE DU SITE"
  end


  # --- note de diagnostic dirigeant ------------------------------------------------------------

  # Le document doit donner envie d'un entretien, jamais permettre de s'en passer : le garde-fou
  # « pas de comment » est une règle absolue du prompt, comme l'anonymisation pour les contenus
  # publics. Il se vérifie par présence, ce que les modèles respectent.
  test "the executive brief forbids any prescription and names the real companies" do
    context = FakeContext.new(replies: [ "a", "b" ])
    run_generator(Generation.create!(user: @user, kind: :executive_brief), context)
    instructions = context.draft_chat.instructions

    assert_includes instructions, "LE DIAGNOSTIC SANS L'ORDONNANCE"
    assert_includes instructions, "aucun plan d'action"
    assert_includes instructions, "Yoplait"
    assert_includes instructions, "## Les questions à poser à votre site"
    assert_includes instructions, "LETTRE D'ACCOMPAGNEMENT"
    assert_includes instructions, "N'ajoute aucun chiffre qui ne figure pas dans le brief"
    # Montrer la sortie, pas la catastrophe : l'ouverture part de ce qui a été accompli, et chaque
    # constat se referme sur ce qu'il rend possible — sinon le lecteur se braque avant la deuxième page.
    assert_includes instructions, "MONTRER LA SORTIE, PAS LA CATASTROPHE"
    assert_includes instructions, "ce que l'entreprise a accompli d'après"
    assert_includes instructions, "aucune flatterie"
    # Première note réelle (17/09/2026) : le modèle avait recopié des notes internes du brief
    # (« a fund that doesn't need me for a redundancy plan ») et brodé sur les réalisations
    # (« Class A cleanroom », la manière d'obtenir un résultat). Deux interdictions de plus.
    assert_includes instructions, "NOTES INTERNES de Cyrille"
    assert_includes instructions, "contexte EXACT du catalogue"
    # Même première note : « incidents » pour des aléas, « audited » pour des comptes déposés, le
    # fonds nommé au lecteur, « gisements » laissé en français, et un « levier unique » contredit par
    # la fin de la note. Glossaire, exactitude des qualificatifs et cohérence, en règles.
    assert_includes instructions, "aléas → unplanned disruptions"
    # Chaque réalisation citée renvoie à sa fiche sur le site, et le chiffre clé est en gras.
    assert_includes instructions, RealisationCatalog.public_url(RealisationCatalog::ITEMS.first)
    assert_includes instructions, "UN seul passage en gras"
    assert_includes instructions, "Des comptes « déposés » ne sont pas"
    assert_includes instructions, "L'actionnaire ou le fonds ne se nomme jamais"
    assert_includes instructions, "aucun mot français ne subsiste dans un texte anglais"
    assert_includes instructions, "levier unique qui changerait tout"
  end

  test "the executive brief hands over the published articles as complementary reading" do
    article = Generation.create!(user: @user, kind: :article, title: "Réduire les rebuts en pharma",
                                 status: :published, published_at: Time.current, output: "## Un\n\nTexte.")
    context = FakeContext.new(replies: [ "a", "b" ])
    run_generator(Generation.create!(user: @user, kind: :executive_brief), context)

    assert_includes context.draft_chat.instructions, "ARTICLES PUBLIÉS PAR CYRILLE"
    assert_includes context.draft_chat.instructions, article.public_url
  end
  # --- note de diagnostic : deux modes, et la relecture automatique des chiffres -----------------

  ANALYSIS = "Le CA passe de 26,8 M€ (2021) à 30 729 278 € en 2025. Frais de personnel 42,7 % du CA. " \
             "Rebuts 4,5 % du CA. Ligne inaugurée en novembre 2023."

  def executive_brief(with_analysis: false, **attrs)
    Generation.create!(user: @user, kind: :executive_brief, input_text: "Signal : annonce de recrutement.",
                       financial_analysis: (ANALYSIS if with_analysis), **attrs)
  end

  def brief_draft(note, letter: "Lettre.")
    "###VERSION_FINALE###\n#{note}\n\n###A_PERSONNALISER###\n- Le destinataire.\n\n###VERSION_COURTE###\n#{letter}"
  end

  test "without a financial analysis the brief is built from public signals" do
    context = FakeContext.new(replies: ["a", "b"])
    run_generator(executive_brief, context)
    instructions = context.draft_chat.instructions

    assert_includes instructions, "MODE SIGNAUX PUBLICS"
    assert_includes instructions, "## Ce que l'on voit de l'extérieur"
    assert_includes instructions, "jusqu'à sept questions"
    assert_includes instructions, "omets la section entière"
    assert_not_includes instructions, "MODE COMPTES"
  end

  test "with a financial analysis the brief reads the accounts and settles discrepancies by precedence" do
    context = FakeContext.new(replies: ["a", "b"])
    run_generator(executive_brief(with_analysis: true), context)
    instructions = context.draft_chat.instructions

    assert_includes instructions, "MODE COMPTES"
    assert_includes instructions, "## Ce que vos comptes disent"
    assert_includes instructions, ContentGenerator::DISCREPANCY_MARKER
    assert_includes instructions, "l'analyse l'emporte et la valeur du brief est ignorée"
    assert_includes instructions, "le brief l'emporte"
    assert_includes instructions, "le calcul montré"
    assert_includes context.draft_chat.question, "ANALYSE FINANCIÈRE VALIDÉE (seule source des chiffres) :\n#{ANALYSIS}"
    # La relecture des chiffres est automatique : le modèle n'a plus de liste à vérifier à produire.
    assert_not_includes instructions, Generation::SECTION_MARKERS[:verify]
    assert_includes instructions, "Aucune liste de chiffres à vérifier"
  end

  test "a brief whose figures all come from the sources gets a clean journal and no correction pass" do
    record = executive_brief(with_analysis: true)
    draft = brief_draft("Revenue reached **€30.7m** in 2025, labour at 42.7%, the line opened in November 2023.")
    context = FakeContext.new(replies: [draft, :echo])

    run_generator(record, context)

    assert_equal 2, context.chats.size, "aucune passe de correction quand rien n'est signalé"
    sections = record.reload.sections
    assert_includes sections[:verify], "Aucune correction"
    assert_equal "Corrections automatiques", record.section_labels[:verify]
    assert_equal "Lettre.", sections[:short]
  end

  test "flagged figures go back to the model, and Ruby writes the journal of what happened" do
    record = executive_brief(with_analysis: true)
    draft = brief_draft("Revenue reached €30.7m, scrap costs €1.38m a year, savings of €777k, absenteeism at 83.3%.")
    corrected = brief_draft("Revenue reached €30.7m, scrap costs €1.38m a year, absenteeism at 83.3%.") +
                "\n###JOURNAL###\n- 1,38 M€ = 30,7 M€ × 4,5 %\n- 83,3 % = 30,7 M€ × 4 %"
    context = FakeContext.new(replies: [draft, corrected, :echo])

    run_generator(record, context)

    correction = context.chats[1]
    assert_includes correction.instructions, "CHIFFRES ABSENTS DES SOURCES :\n- €1.38m\n- €777k\n- 83.3%"
    assert_includes correction.instructions, ANALYSIS
    assert_equal draft, correction.question
    journal = record.reload.sections[:verify]
    assert_includes journal, "- Corrigé ou retiré : €777k"
    assert_includes journal, "- Conservé, calcul vérifié : €1.38m = 30,7 M€ × 4,5 %"
    assert_includes journal, "- Non résolu, à contrôler : 83.3%"
    assert_not_includes record.output, "###JOURNAL###"
    assert_includes record.sections[:final], "absenteeism at 83.3%"
  end

  # Une première version arrêtait la génération sur une contradiction : la note 203 du 18/09/2026
  # est morte sur une date que le brief tenait de la presse. La règle tranche, le journal le dit.
  test "discrepancies settled by the model go to the journal instead of halting the generation" do
    record = executive_brief(with_analysis: true)
    draft = brief_draft("Revenue reached €30.7m in 2025.") +
            "\n\n#{ContentGenerator::DISCREPANCY_MARKER}\nDate de la ligne : novembre 2024, brief, contre novembre " \
            "2023 dans l'analyse.\n- Produits : suppositoires, brief, contre « formes sèches » dans l'analyse."
    context = FakeContext.new(replies: [draft, :echo])

    run_generator(record, context)

    assert record.reload.generated?
    journal = record.sections[:verify]
    assert_includes journal, "Écarts entre le brief et l'analyse, tranchés par la règle"
    assert_includes journal, "- Date de la ligne : novembre 2024, brief, contre novembre 2023 dans l'analyse."
    assert_includes journal, "- Produits : suppositoires, brief"
    assert_includes journal, "Aucune correction"
    assert_not_includes record.output, ContentGenerator::DISCREPANCY_MARKER
    assert_equal "Lettre.", record.sections[:short]
  end

  test "an empty discrepancy list leaves the journal to the figures alone" do
    record = executive_brief(with_analysis: true)
    draft = brief_draft("Revenue reached €30.7m in 2025.") + "\n\n#{ContentGenerator::DISCREPANCY_MARKER}\nAucun."
    context = FakeContext.new(replies: [draft, :echo])

    run_generator(record, context)

    assert_equal "Aucune correction : chaque chiffre de la note figure dans les sources.",
                 record.reload.sections[:verify]
  end

  test "a brief without markers is stored as is" do
    context = FakeContext.new(replies: ["Texte sans marqueurs, €777k.", "Texte sans marqueurs, €777k."])
    record = executive_brief

    run_generator(record, context)

    assert_equal "Texte sans marqueurs, €777k.", record.reload.output
  end
end
