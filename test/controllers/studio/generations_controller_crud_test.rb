require "test_helper"

module Studio
  # Complète generations_controller_test.rb sur les actions d'édition restées non couvertes.
  class GenerationsControllerCrudTest < ActionDispatch::IntegrationTest
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
        patch regenerate_studio_generation_path(@generation),
              params: { generation: { llm_model: @generation.llm_model } }
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
  end
end
