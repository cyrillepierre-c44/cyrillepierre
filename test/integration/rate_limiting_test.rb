require "test_helper"

# Rack::Attack est coupé pour le reste de la suite (test_helper.rb) : chaque test ici le
# réactive avec un compteur mémoire vierge, isolé des autres tests, puis le recoupe.
class RateLimitingTest < ActionDispatch::IntegrationTest
  MAMMOUTH_URL = "https://api.mammouth.ai/v1/chat/completions".freeze

  setup do
    Rack::Attack.enabled = true
    @previous_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rack::Attack.cache.store = @previous_store
    Rack::Attack.enabled = false
  end

  def stub_llm
    stub_request(:post, MAMMOUTH_URL).to_return(
      status: 200,
      body: { choices: [ { message: { content: "Bonjour !" } } ] }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  # Chaque hit sur ces endpoints déclenche un appel Mammouth payant : le throttle est un
  # garde-fou de facturation avant d'être une mesure de sécurité.
  test "the paid LLM endpoints stop answering after 20 requests in a minute" do
    stub_llm

    20.times do
      post contact_chat_path, params: { message: "Bonjour" }
      assert_response :success
    end

    post contact_chat_path, params: { message: "Bonjour" }

    assert_response :too_many_requests
    assert_equal "60", response.headers["retry-after"]
    assert_includes response.body, "Trop de requêtes"
  end

  # Le compteur LLM est partagé entre les trois endpoints : ils tapent tous sur Mammouth,
  # les compter séparément triplerait le budget réellement autorisé.
  test "the three LLM endpoints share the same counter" do
    stub_llm

    10.times { post contact_chat_path, params: { message: "Bonjour" } }
    10.times { post contact_infer_company_path, params: { company: "Une Usine SA" } }

    post contact_summarize_path, params: { history: [] }

    assert_response :too_many_requests
  end

  test "the contact form stops accepting submissions after 5 in an hour" do
    params = { contact_name: "Jean", contact_email: "jean@example.com",
               contact_summary: "Résumé." }

    5.times do
      post contact_path, params: params
      assert_response :redirect
    end

    post contact_path, params: params

    assert_response :too_many_requests
  end

  test "sign-in attempts are throttled after 10 in 20 minutes" do
    10.times do
      post user_session_path, params: { user: { email: "x@example.com", password: "wrong" } }
      assert_not_equal 429, response.status
    end

    post user_session_path, params: { user: { email: "x@example.com", password: "wrong" } }

    assert_response :too_many_requests
  end

  test "browsing the site normally is not throttled" do
    get root_path

    assert_response :success
  end
end
