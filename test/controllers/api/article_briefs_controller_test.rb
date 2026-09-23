require "test_helper"

module Api
  # Le brief du lundi devient un brouillon d'article dans le Studio, chez l'administrateur, prêt
  # à être généré ; le même brief renvoyé retrouve le brouillon au lieu d'en créer un second.
  class ArticleBriefsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @token = ENV["VEILLE_API_TOKEN"]
      ENV["VEILLE_API_TOKEN"] = "jeton-de-test"
      @editor = User.create!(email: "brief-editor@example.com", password: "password123", role: :editor)
      @admin = User.create!(email: "brief-admin@example.com", password: "password123", role: :admin)
    end

    teardown { ENV["VEILLE_API_TOKEN"] = @token }

    def post_brief(token: "jeton-de-test", **payload)
      post api_article_briefs_path, params: payload.to_json,
                                    headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
    end

    test "creates a draft article for the admin, with the brief as source, and returns its Studio address" do
      assert_difference -> { Generation.count }, 1 do
        post_brief(title: "Comment budgéter une mise aux normes HSE ?", brief: "N°08 — 930 K€ investis…")
      end

      assert_response :created
      body = JSON.parse(response.body)
      draft = Generation.find(body["id"])
      assert_equal @admin, draft.user
      assert draft.article?
      assert draft.draft?
      assert_equal "Comment budgéter une mise aux normes HSE ?", draft.title
      assert_equal "N°08 — 930 K€ investis…", draft.input_text
      assert_nil draft.output
      assert body["created"]
      assert_equal studio_generation_url(draft), body["studio_url"]
    end

    test "the same title sent again finds the empty draft instead of creating another" do
      post_brief(title: "Sujet", brief: "v1")
      first = JSON.parse(response.body)["id"]

      assert_no_difference -> { Generation.count } do
        post_brief(title: "Sujet", brief: "v2")
      end
      body = JSON.parse(response.body)
      assert_equal first, body["id"]
      assert_not body["created"]

      Generation.find(first).update!(output: "Article rédigé", status: :generated)
      assert_difference -> { Generation.count }, 1 do
        post_brief(title: "Sujet", brief: "v3")
      end
    end

    test "rejects a wrong token and a missing title, and says so when no admin exists" do
      post_brief(title: "x", brief: "y", token: "faux")
      assert_response :unauthorized

      post_brief(brief: "sans titre")
      assert_response :bad_request

      @admin.destroy
      post_brief(title: "x", brief: "y")
      assert_response :unprocessable_entity
    end

    test "the draft shows in the Studio with a Générer button and its brief" do
      post_brief(title: "Sujet de la semaine", brief: "Le brief.")
      draft = Generation.find(JSON.parse(response.body)["id"])
      sign_in @admin

      get studio_generation_path(draft)

      assert_response :success
      assert_select "input[type=submit][value=Générer]"
      assert_select "h1", text: /Sujet de la semaine/
    end
  end
end
