require "test_helper"

# Couvre l'envoi du visuel et les chemins de panne de LinkedinPublisher, en interceptant au
# niveau HTTP plutôt qu'en remplaçant Faraday.
class LinkedinPublisherImageTest < ActiveSupport::TestCase
  API = LinkedinPublisher::API_BASE
  UPLOAD_URL = "https://upload.linkedin.example/put".freeze
  IMAGE_URN = "urn:li:image:abc".freeze

  setup do
    @user = User.create!(email: "publish-#{SecureRandom.hex(4)}@example.com", password: "password123",
                         linkedin_access_token: "token", linkedin_token_expires_at: 60.days.from_now,
                         linkedin_member_urn: "member-123")
    @generation = Generation.create!(user: @user, kind: :linkedin_post, output: "Un post avec visuel.")
    @generation.visual.attach(io: StringIO.new("fake-png"), filename: "visual.png", content_type: "image/png")
  end

  # `wait_for_image_ready` attend une seconde entre deux sondages. Neutraliser cette pause
  # garde la suite rapide tout en exerçant réellement la boucle.
  def without_pauses
    LinkedinPublisher.class_eval { def sleep(*) = nil }
    yield
  ensure
    LinkedinPublisher.send(:remove_method, :sleep)
  end

  def stub_upload_initialisation
    stub_request(:post, "#{API}/rest/images?action=initializeUpload").to_return(
      status: 200,
      body: { value: { uploadUrl: UPLOAD_URL, image: IMAGE_URN } }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
    stub_request(:put, UPLOAD_URL).to_return(status: 201)
  end

  def stub_post_creation
    stub_request(:post, "#{API}/rest/posts")
      .to_return(status: 201, headers: { "x-restli-id" => "urn:li:share:999" })
  end

  def stub_image_status(*statuses)
    responses = statuses.map do |s|
      { status: 200, body: { status: s }.to_json, headers: { "Content-Type" => "application/json" } }
    end
    stub_request(:get, %r{#{Regexp.escape(API)}/rest/images/}).to_return(responses)
  end

  test "waits for the uploaded image to be processed before creating the post" do
    stub_upload_initialisation
    stub_image_status("PROCESSING", "AVAILABLE")
    stub_post_creation

    without_pauses { LinkedinPublisher.call(@generation) }

    assert_equal "urn:li:share:999", @generation.reload.linkedin_post_urn
    assert_requested :get, %r{/rest/images/}, times: 2
  end

  # Nos scopes ne donnent pas toujours accès en lecture à l'image : on retombe sur une attente
  # forfaitaire plutôt que de faire échouer toute la publication.
  test "falls back to a flat wait when the status endpoint is unreachable" do
    stub_upload_initialisation
    stub_request(:get, %r{#{Regexp.escape(API)}/rest/images/}).to_timeout
    stub_post_creation

    without_pauses { LinkedinPublisher.call(@generation) }

    assert @generation.reload.linkedin_published_at.present?
  end

  test "falls back to a flat wait when the status endpoint refuses access" do
    stub_upload_initialisation
    stub_request(:get, %r{#{Regexp.escape(API)}/rest/images/}).to_return(status: 403, body: "")
    stub_post_creation

    without_pauses { LinkedinPublisher.call(@generation) }

    assert @generation.reload.linkedin_published_at.present?
  end

  # Bug déjà rencontré : un PUT refusé laissait créer un post référençant une image jamais
  # envoyée, que LinkedIn retirait ensuite.
  test "raises when the image upload itself is refused" do
    stub_request(:post, "#{API}/rest/images?action=initializeUpload").to_return(
      status: 200,
      body: { value: { uploadUrl: UPLOAD_URL, image: IMAGE_URN } }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
    stub_request(:put, UPLOAD_URL).to_return(status: 400)

    error = assert_raises(LinkedinPublisher::Error) { LinkedinPublisher.call(@generation) }

    assert_includes error.message, "Échec de l'envoi de l'image"
    assert_nil @generation.reload.linkedin_post_urn
  end

  test "surfaces the message LinkedIn returns in its JSON error body" do
    stub_request(:post, "#{API}/rest/images?action=initializeUpload")
      .to_return(status: 422, body: { message: "Invalid owner urn" }.to_json)

    error = assert_raises(LinkedinPublisher::Error) { LinkedinPublisher.call(@generation) }

    assert_includes error.message, "Invalid owner urn"
    assert_includes error.message, "422"
  end

  # Une erreur 426 "version not active" revient en HTML, pas en JSON : le message ne doit pas
  # se perdre dans une exception de parsing.
  test "falls back to the raw body when the error is not JSON" do
    stub_request(:post, "#{API}/rest/images?action=initializeUpload")
      .to_return(status: 426, body: "<html>Version not active</html>")

    error = assert_raises(LinkedinPublisher::Error) { LinkedinPublisher.call(@generation) }

    assert_includes error.message, "426"
    assert_includes error.message, "Version not active"
  end
end
