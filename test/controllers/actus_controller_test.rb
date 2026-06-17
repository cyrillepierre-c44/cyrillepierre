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
    assert_includes @response.body, "Le contenu de l'actu"
  end

  test "show 404s for an unpublished actu" do
    actu = Generation.create!(user: @user, kind: :site_actu, status: :generated, output: "Pas encore publiée")
    get actu_path(actu)
    assert_response :not_found
  end
end
