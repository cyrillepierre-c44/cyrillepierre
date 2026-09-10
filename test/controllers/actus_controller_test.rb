require "test_helper"

class ActusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "editor@example.com", password: "password123")
  end

  test "index only lists published site_actu generations" do
    published = Generation.create!(user: @user, kind: :site_actu, status: :published, published_at: Time.current, output: "Actu publiée")
    Generation.create!(user: @user, kind: :site_actu, status: :generated, output: "Actu brouillon")
    Generation.create!(user: @user, kind: :linkedin_post, status: :published, published_at: Time.current, output: "Post LinkedIn")

    get actus_path
    assert_response :success
    assert_includes @response.body, "Actu publiée"
    assert_not_includes @response.body, "Actu brouillon"
    assert_not_includes @response.body, "Post LinkedIn"
    assert published.published?
  end

  test "show renders a published actu" do
    actu = Generation.create!(user: @user, kind: :site_actu, status: :published, published_at: Time.current, output: "Le contenu de l'actu")
    get actu_path(actu)
    assert_response :success
    # Le corps est rendu par ArticleFormatter, qui échappe l'apostrophe : on vérifie le texte
    # affiché plutôt que la chaîne brute du HTML.
    assert_select ".actu-body p", text: "Le contenu de l'actu"
  end

  test "show 404s for an unpublished actu" do
    actu = Generation.create!(user: @user, kind: :site_actu, status: :generated, output: "Pas encore publiée")
    get actu_path(actu)
    assert_response :not_found
  end
  test "the list badges both formats so the reader knows what he opens" do
    Generation.create!(user: @user, kind: :site_actu, status: :published,
                       published_at: 2.days.ago, output: "Une brève")
    Generation.create!(user: @user, kind: :article, status: :published,
                       published_at: 1.day.ago, title: "Un article", output: "## Section\n\nDu texte.")

    get actus_path

    assert_select ".actu-card-kind", 2
    assert_select ".actu-card-kind--brief", 1
    assert_select ".actu-card-kind", text: /Article/
  end

  test "the page announces both formats, not only the news" do
    get actus_path

    assert_select "h1", text: /Articles/
    assert_select "title", text: /Articles & actus/
  end

  test "an entry names its format next to its date" do
    article = Generation.create!(user: @user, kind: :article, status: :published,
                                 published_at: Time.current, title: "Un article", output: "Du texte.")

    get actu_path(article)

    assert_select ".section-eyebrow", text: /Article ·/
  end
end
