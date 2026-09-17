require "test_helper"

module Studio
  # Complète generations_controller_test.rb sur les actions d'édition restées non couvertes.
  class GenerationsControllerCrudTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    setup do
      @editor = User.create!(email: "crud-editor@example.com", password: "password123", role: :editor)
      @admin = User.create!(email: "crud-admin@example.com", password: "password123", role: :admin)
      @generation = Generation.create!(user: @editor, kind: :linkedin_post, output: "Un post.",
                                       status: :generated)
      sign_in @editor
    end

    def stubbing_generator(&block)
      ContentGenerator.stub(:call, ->(g) { g.update!(output: "regénéré", status: :generated) }, &block)
    end

    test "new renders the creation form for a given kind" do
      get new_studio_generation_path(kind: "cover_letter")

      assert_response :success
    end

    test "new pre-fills the brief handed over by a prospect sheet" do
      get new_studio_generation_path(kind: "commercial_proposal", title: "Proposition — Fonderie Sud",
                                     input_text: "Client : Fonderie Sud")

      assert_response :success
      assert_select "input[name=?][value=?]", "generation[title]", "Proposition — Fonderie Sud"
      assert_select "textarea[name=?]", "generation[input_text]", text: /Fonderie Sud/
    end

    test "an article shows its rendered preview and its word count" do
      article = Generation.create!(user: @editor, kind: :article, title: "Pourquoi le TRS ment",
                                   status: :generated, output: "## Une section\n\nDeux mots ici.")

      get studio_generation_path(article)

      assert_response :success
      assert_select ".studio-article-preview h1", text: "Pourquoi le TRS ment"
      assert_select ".studio-article-preview h2", text: "Une section"
      assert_select ".studio-field-hint", text: /5 mots/
    end

    test "a published article offers to announce itself on LinkedIn" do
      article = Generation.create!(user: @editor, kind: :article, status: :published,
                                   published_at: Time.current, title: "Passer en 3x8",
                                   output: "Du texte.")

      get studio_generation_path(article)

      assert_select "a[href=?]",
                    new_studio_generation_path(kind: "linkedin_post", source_article_id: article.id)
    end

    test "an unpublished article offers nothing to announce" do
      article = Generation.create!(user: @editor, kind: :article, status: :generated, output: "Du texte.")

      get studio_generation_path(article)

      assert_select "a[href*=?]", "source_article_id", count: 0
    end

    test "the creation form carries the article the post must promote" do
      article = Generation.create!(user: @editor, kind: :article, status: :published,
                                   published_at: Time.current, title: "Passer en 3x8",
                                   output: "Du texte.")

      get new_studio_generation_path(kind: "linkedin_post", source_article_id: article.id)

      assert_response :success
      assert_select "input[name=?][value=?]", "generation[source_article_id]", article.id.to_s
      assert_select ".studio-field-hint", text: /Passer en 3x8/
    end

    # 27 secondes mesurées en production pour 30 autorisées par Heroku : la génération ne peut
    # plus se faire dans la requête web.
    test "creation hands the work to a background job instead of blocking the request" do
      assert_enqueued_with(job: ContentGenerationJob) do
        post studio_generations_path, params: { generation: { kind: "linkedin_post", input_text: "x" } }
      end

      created = Generation.order(:created_at).last
      assert_redirected_to studio_generation_path(created)
      assert created.generating?, "la page doit annoncer l'attente dès la redirection"
    end

    test "regeneration is enqueued too, and keeps the previous text meanwhile" do
      assert_enqueued_with(job: ContentGenerationJob) do
        patch regenerate_studio_generation_path(@generation),
              params: { generation: { llm_model: @generation.llm_model } }
      end

      assert_equal "Un post.", @generation.reload.output
      assert @generation.generating?
    end

    test "a generation in progress announces itself and refreshes on its own" do
      @generation.update!(generating_since: Time.current)

      get studio_generation_path(@generation)

      assert_select ".studio-progress-inline", 1
      assert_select "meta[http-equiv=refresh]", 1
    end

    test "a generation that never came back says so instead of waiting forever" do
      @generation.update!(output: nil, generating_since: (Generation::GENERATION_TIMEOUT + 1.minute).ago)

      get studio_generation_path(@generation)

      assert_select "meta[http-equiv=refresh]", 0
      assert_select ".studio-empty", text: /n'a pas abouti/
    end

    test "edit renders the edition form" do
      get edit_studio_generation_path(@generation)

      assert_response :success
    end

    test "update saves the manual edits and redirects to the generation" do
      patch studio_generation_path(@generation), params: { generation: { title: "Nouveau titre",
                                                                        output: "Texte corrigé à la main." } }

      assert_redirected_to studio_generation_path(@generation)
      assert_equal "Texte corrigé à la main.", @generation.reload.output
      assert_equal "Nouveau titre", @generation.title
    end

    test "update re-renders the form when the record is invalid" do
      patch studio_generation_path(@generation), params: { generation: { llm_model: "modele-inexistant" } }

      assert_response :unprocessable_entity
      assert_not_equal "modele-inexistant", @generation.reload.llm_model
    end

    test "create re-renders the form when the record is invalid" do
      assert_no_difference("Generation.count") do
        post studio_generations_path, params: { generation: { kind: "linkedin_post",
                                                              llm_model: "modele-inexistant" } }
      end

      assert_response :unprocessable_entity
    end

    test "destroy removes the generation and goes back to the list" do
      assert_difference("Generation.count", -1) do
        delete studio_generation_path(@generation)
      end

      assert_redirected_to studio_generations_path
    end

    test "regenerate runs the generator again" do
      stubbing_generator do
        perform_enqueued_jobs do
          patch regenerate_studio_generation_path(@generation),
                params: { generation: { llm_model: @generation.llm_model } }
        end
      end

      assert_redirected_to studio_generation_path(@generation)
      assert_equal "regénéré", @generation.reload.output
    end

    # `regenerate` traite le modèle comme optionnel (`if ... .present?`) mais passe par
    # `generation_params`, qui exige la clé `generation`. Le formulaire de la page embarque
    # toujours le sélecteur de modèle, donc le cas ne se produit pas aujourd'hui ; ce test fige
    # la fragilité pour qu'un formulaire allégé ne casse pas la régénération en silence.
    test "regenerate rejects a request that omits the generation params entirely" do
      patch regenerate_studio_generation_path(@generation)

      assert_response :bad_request
    end

    # Le formulaire de régénération permet de changer de modèle au passage.
    test "regenerate switches the model when one is submitted" do
      model = Generation::LLM_MODELS.keys.last

      stubbing_generator do
        patch regenerate_studio_generation_path(@generation), params: { generation: { llm_model: model } }
      end

      assert_equal model, @generation.reload.llm_model
    end

    test "regenerate keeps the current model when none is submitted" do
      before = @generation.llm_model

      stubbing_generator do
        patch regenerate_studio_generation_path(@generation), params: { generation: { title: "Titre" } }
      end

      assert_redirected_to studio_generation_path(@generation)
      assert_equal before, @generation.reload.llm_model
    end

    test "generate_visual runs the image generator with the submitted model" do
      model = Generation::IMAGE_MODELS.keys.last

      VisualGenerator.stub(:call, ->(g) { g }) do
        patch generate_visual_studio_generation_path(@generation),
              params: { generation: { image_model: model } }
      end

      assert_redirected_to studio_generation_path(@generation)
      assert_equal model, @generation.reload.image_model
    end

    test "generate_visual keeps the current image model when none is submitted" do
      before = @generation.image_model

      VisualGenerator.stub(:call, ->(g) { g }) do
        patch generate_visual_studio_generation_path(@generation)
      end

      assert_redirected_to studio_generation_path(@generation)
      assert_equal before, @generation.reload.image_model
    end

    test "unpublish sends a site actu back to generated and clears the date" do
      actu = Generation.create!(user: @admin, kind: :site_actu, output: "Une actu.",
                                status: :published, published_at: Time.current)
      sign_out @editor
      sign_in @admin

      patch unpublish_studio_generation_path(actu)

      assert_redirected_to studio_generation_path(actu)
      actu.reload
      assert actu.generated?
      assert_nil actu.published_at
    end

    # --- note de diagnostic : document imprimable ----------------------------------------------

    def executive_brief(**attrs)
      output = "#{Generation::SECTION_MARKERS[:final]}\nIntro.\n\n## Ce que vos comptes disent\n\nUn **constat**.\n" \
               "#{Generation::SECTION_MARKERS[:short]}\nLa lettre."
      Generation.create!({ user: @editor, kind: :executive_brief, title: "Note — Fonderie Sud",
                           status: :generated, output: output }.merge(attrs))
    end

    # --- formulaire : l'ordre suit la pensée, pas l'histoire du code -----------------------------

    test "the form asks in the order one thinks: what, from what, how, title, model" do
      get new_studio_generation_path

      assert_response :success
      titles = css_select(".studio-card-subtitle").map(&:text).map(&:strip)
      assert_equal [ "1. Type de contenu", "2. Source", "3. Précisions", "4. Titre (optionnel)", "5. Modèle IA" ], titles
    end

    # L'orientation ne concerne que les contenus publics, la réalisation que le post, et l'aide de la
    # source change par type : le gabarit porte les types concernés, le contrôleur Stimulus affiche.
    test "the form scopes its optional fields and hints to the kinds they concern" do
      get new_studio_generation_path(kind: "executive_brief")

      assert_select "[data-studio-generation-target=orientationField][data-kinds=?]", "linkedin_post site_actu article"
      assert_select "[data-studio-generation-target=realisationField]", 1
      assert_select "[data-studio-generation-target=sourceHint][data-kinds=executive_brief]", text: /analyse financière validée/
      assert_select "[data-studio-generation-target=sourceHint][data-kinds=?]", "site_actu article"
      assert_select "input[type=checkbox][name=?]", "generation[generate_visual]", 1
    end

    test "the executive brief opens as a standalone printable document" do
      brief = executive_brief

      get document_studio_generation_path(brief)

      assert_response :success
      assert_select "nav.navbar", 0, "le document ne doit pas embarquer la navigation du site"
      assert_select "h1", text: "Note — Fonderie Sud"
      assert_select ".doc h2", text: "Ce que vos comptes disent"
      assert_select ".doc strong", text: "constat"
      assert_select ".meta .confidential", text: "Confidentiel"
      assert_select "meta[name=robots][content=?]", "noindex, nofollow"
      assert_not_includes @response.body, "La lettre", "la lettre d'accompagnement ne fait pas partie du document"
    end

    test "the printable document does not exist for another kind of content" do
      get document_studio_generation_path(@generation)

      assert_response :not_found
    end

    test "the printable document does not exist before the brief is generated" do
      get document_studio_generation_path(executive_brief(output: nil))

      assert_response :not_found
    end

    test "the printable document is reserved to its owner or an admin" do
      brief = executive_brief
      other = User.create!(email: "crud-other@example.com", password: "password123", role: :editor)
      sign_in other

      get document_studio_generation_path(brief)

      assert_response :not_found
    end

    test "the show page links to the printable document for an executive brief" do
      brief = executive_brief

      get studio_generation_path(brief)

      assert_response :success
      assert_select "a[href=?]", document_studio_generation_path(brief), text: /document imprimable/
      assert_select ".studio-section-title", text: "Lettre d'accompagnement"
    end
  end
end
