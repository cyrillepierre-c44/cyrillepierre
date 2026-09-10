require "test_helper"

class ContactsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  MAMMOUTH_URL = "https://api.mammouth.ai/v1/chat/completions".freeze
  FALLBACK = "Je rencontre une difficulté technique. Écrivez directement à cyrille.pierre@gmail.com".freeze

  def stub_llm(content, status: 200)
    stub_request(:post, MAMMOUTH_URL).to_return(
      status: status,
      body: { choices: [ { message: { content: content } } ] }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  # La passerelle répond 200 avec une phrase coupée : seul finish_reason trahit la troncature.
  def stub_truncated_then(content)
    stub_request(:post, MAMMOUTH_URL)
      .to_return(
        status: 200,
        body: { choices: [ { message: { content: "Un outil n'a de valeur que s" }, finish_reason: "length" } ] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
      .then.to_return(
        status: 200,
        body: { choices: [ { message: { content: content }, finish_reason: "stop" } ] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def last_llm_payload
    JSON.parse(WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last.body)
  end

  test "the contact page renders" do
    get contact_path

    assert_response :success
  end

  # --- infer_company ---------------------------------------------------------

  test "infer_company returns nulls without calling the LLM when the company is blank" do
    post contact_infer_company_path, params: { company: "   " }

    assert_response :success
    assert_equal({ "sector" => nil, "size" => nil }, response.parsed_body)
    assert_not_requested :post, MAMMOUTH_URL
  end

  test "infer_company returns the sector and size parsed from the LLM answer" do
    stub_llm({ secteur: "agroalimentaire", effectif: "~200 personnes" }.to_json)

    post contact_infer_company_path, params: { company: "Une Usine SA" }

    assert_equal "agroalimentaire", response.parsed_body["sector"]
    assert_equal "~200 personnes", response.parsed_body["size"]
  end

  test "infer_company returns nulls when the LLM does not know the company" do
    stub_llm("null")

    post contact_infer_company_path, params: { company: "Société Inconnue" }

    assert_equal({ "sector" => nil, "size" => nil }, response.parsed_body)
  end

  # Le modèle répond parfois avec du texte autour du JSON : ça ne doit pas lever une 500.
  test "infer_company degrades gracefully when the LLM answer is not valid JSON" do
    stub_llm("Voici ma réponse : { secteur: agroalimentaire }")

    post contact_infer_company_path, params: { company: "Une Usine SA" }

    assert_response :success
    assert_equal({ "sector" => nil, "size" => nil }, response.parsed_body)
  end

  test "infer_company blanks out empty fields returned by the LLM" do
    stub_llm({ secteur: "pharmaceutique", effectif: "" }.to_json)

    post contact_infer_company_path, params: { company: "Une Usine SA" }

    assert_equal "pharmaceutique", response.parsed_body["sector"]
    assert_nil response.parsed_body["size"]
  end

  # --- chat ------------------------------------------------------------------

  test "chat returns the assistant reply and reports it is not ready yet" do
    stub_llm("Bonjour ! Quel est votre principal défi ?")

    post contact_chat_path, params: { initial: "true", themes: [ "Excellence opérationnelle" ] }

    assert_equal "Bonjour ! Quel est votre principal défi ?", response.parsed_body["reply"]
    assert_not response.parsed_body["ready"]
  end

  test "chat flags the conversation as ready when the model emits the marker" do
    stub_llm("Merci, j'ai tout ce qu'il me faut !\n##READY##")

    post contact_chat_path, params: { message: "Un signe concret de réussite." }

    assert response.parsed_body["ready"]
  end

  test "chat replays the conversation history to the model" do
    stub_llm("Et avez-vous déjà essayé des approches ?")

    post contact_chat_path, params: {
      message: "Réduire les arrêts machine.",
      history: [ { role: "assistant", content: "Quel est votre défi ?" },
                { role: "user", content: "La productivité." } ]
    }

    roles = last_llm_payload["messages"].map { |m| m["role"] }
    assert_equal %w[system assistant user user], roles
  end

  # Le secteur et la taille saisis par le visiteur sont certains : le prompt doit interdire
  # de reposer la question.
  test "chat injects the visitor context into the system prompt when it is known" do
    stub_llm("Bonjour !")

    post contact_chat_path, params: { initial: "true", sector: "pharmaceutique", size: "400 personnes" }

    system_prompt = last_llm_payload["messages"].first["content"]
    assert_includes system_prompt, "CONTEXTE VISITEUR"
    assert_includes system_prompt, "pharmaceutique"
    assert_includes system_prompt, "400 personnes"
  end

  # Le secteur seul suffit à personnaliser l'accueil : la formulation du prompt doit s'accorder
  # au singulier plutôt que d'annoncer une taille qu'on ignore.
  test "chat adapts the wording when only the sector is known" do
    stub_llm("Bonjour !")

    post contact_chat_path, params: { initial: "true", sector: "pharmaceutique" }

    system_prompt = last_llm_payload["messages"].first["content"]
    assert_includes system_prompt, "CONTEXTE VISITEUR"
    assert_includes system_prompt, "pharmaceutique"
    assert_not_includes system_prompt, "et la taille"
  end

  test "chat omits the visitor context block when nothing is known" do
    stub_llm("Bonjour !")

    post contact_chat_path, params: { initial: "true" }

    system_prompt = last_llm_payload["messages"].first["content"]
    assert_not_includes system_prompt, "CONTEXTE VISITEUR"
    assert_includes system_prompt, "non précisés"
  end

  test "chat never leaks internal catalogue identifiers into the prompt instructions" do
    stub_llm("Bonjour !")

    post contact_chat_path, params: { initial: "true" }

    system_prompt = last_llm_payload["messages"].first["content"]
    assert_includes system_prompt, "Ne cite jamais les identifiants internes"
  end

  # --- summarize -------------------------------------------------------------

  test "summarize returns the markdown summary" do
    stub_llm("🏭 **Contexte :** atelier artisanal")

    post contact_summarize_path, params: { history: [ { role: "user", content: "Nous sommes 30." } ] }

    assert_equal "🏭 **Contexte :** atelier artisanal", response.parsed_body["summary"]
  end

  test "summarize passes the verified company data as established facts" do
    stub_llm("résumé")

    post contact_summarize_path, params: { sector: "automobile", size: "2 000 personnes",
                                           themes: [ "Performance industrielle" ] }

    instructions = last_llm_payload["messages"].last["content"]
    assert_includes instructions, "Données vérifiées sur l'entreprise"
    assert_includes instructions, "automobile"
    assert_includes instructions, "2 000 personnes"
  end

  test "summarize forbids inventing figures when the company data is unknown" do
    stub_llm("résumé")

    post contact_summarize_path, params: { history: [] }

    instructions = last_llm_payload["messages"].last["content"]
    assert_not_includes instructions, "Données vérifiées sur l'entreprise"
    assert_includes instructions, "N'invente JAMAIS un effectif"
  end

  # --- create ----------------------------------------------------------------

  test "create sends the notification and the client confirmation, then redirects" do
    assert_enqueued_emails 2 do
      post contact_path, params: { contact_name: "Jean Dupont", contact_email: "jean@example.com",
                                   contact_themes: [ "Excellence opérationnelle" ],
                                   contact_summary: "Résumé de la demande." }
    end

    assert_redirected_to root_path
    assert_equal "Votre demande a bien été envoyée ! Je vous réponds sous 24h.", flash[:notice]
  end

  test "create records the visitor as a prospect with the qualified context" do
    history = [ { role: "assistant", content: "Quel est votre défi ?" },
                { role: "user", content: "Le TRS baisse." } ].to_json

    assert_difference("Prospect.count", 1) do
      post contact_path, params: { contact_name: "Jean Dupont", contact_email: "jean@example.com",
                                   contact_company: "Fonderie Sud", contact_phone: "0600000000",
                                   contact_sector: "métallurgie", contact_size: "~120 personnes",
                                   contact_themes: [ "Excellence opérationnelle" ],
                                   contact_summary: "Résumé de la demande.",
                                   contact_precision: "Urgent.", contact_history: history }
    end

    prospect = Prospect.order(:created_at).last
    assert_equal "Fonderie Sud", prospect.company
    assert_equal "métallurgie", prospect.sector
    assert_equal "~120 personnes", prospect.company_size
    assert_equal [ "Excellence opérationnelle" ], prospect.themes
    assert prospect.source_site_contact?
    assert prospect.nouveau?
    assert_includes prospect.conversation, "Visiteur : Le TRS baisse."
    assert_includes prospect.conversation, "Assistant : Quel est votre défi ?"
  end

  test "create keeps a non JSON history as is" do
    post contact_path, params: { contact_name: "Jean Dupont", contact_email: "jean@example.com",
                                 contact_history: "Historique déjà en texte" }

    assert_equal "Historique déjà en texte", Prospect.order(:created_at).last.conversation
  end

  test "create still answers the visitor when the prospect cannot be saved" do
    Prospect.stub(:record_contact_request, ->(**) { raise ActiveRecord::RecordInvalid.new(Prospect.new) }) do
      assert_no_difference("Prospect.count") do
        post contact_path, params: { contact_name: "Jean Dupont", contact_email: "jean@example.com" }
      end
    end

    assert_redirected_to root_path
    assert_equal "Votre demande a bien été envoyée ! Je vous réponds sous 24h.", flash[:notice]
  end

  # --- call_llm : troncature par les tokens de réflexion ---------------------

  test "asks for a token budget large enough to survive the model's reasoning" do
    stub_llm("Bonjour")

    post contact_chat_path, params: { message: "Bonjour" }

    assert_equal ContactsController::LLM_MAX_TOKENS, last_llm_payload["max_tokens"]
    assert_nil last_llm_payload["reasoning_effort"]
  end

  test "retries without reasoning when the answer comes back truncated" do
    stub_truncated_then("L'adoption par les équipes terrain est la clé.")

    post contact_chat_path, params: { message: "Comment faire adopter l'outil ?" }

    assert_equal "L'adoption par les équipes terrain est la clé.", JSON.parse(response.body)["reply"]
    assert_equal ContactsController::NO_REASONING_EFFORT, last_llm_payload["reasoning_effort"]
    assert_requested :post, MAMMOUTH_URL, times: 2
  end

  test "a truncated summary is regenerated rather than sent as is" do
    stub_truncated_then("🏭 **Contexte :** Atelier de production.\n\n🎯 **Enjeu :** Adoption terrain.")

    post contact_summarize_path, params: { history: [ { role: "user", content: "Digitaliser l'atelier." } ] }

    assert_includes JSON.parse(response.body)["summary"], "Enjeu"
  end

  test "keeps the truncated answer when the retry brings back nothing" do
    stub_request(:post, MAMMOUTH_URL)
      .to_return(
        status: 200,
        body: { choices: [ { message: { content: "Réponse coupée" }, finish_reason: "length" } ] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
      .then.to_return(status: 500, body: { error: "boom" }.to_json)

    post contact_chat_path, params: { message: "Bonjour" }

    assert_equal "Réponse coupée", JSON.parse(response.body)["reply"]
  end

  # --- call_llm : les chemins de panne --------------------------------------

  test "returns a fallback message when the gateway answers without any choice" do
    stub_request(:post, MAMMOUTH_URL).to_return(status: 500, body: { error: "boom" }.to_json)

    post contact_chat_path, params: { message: "Bonjour" }

    assert_response :success
    assert_equal FALLBACK, response.parsed_body["reply"]
  end

  test "returns a fallback message when the gateway is unreachable" do
    stub_request(:post, MAMMOUTH_URL).to_timeout

    post contact_chat_path, params: { message: "Bonjour" }

    assert_response :success
    assert_equal FALLBACK, response.parsed_body["reply"]
  end

  test "sends the API key and the expected model to Mammouth" do
    stub_llm("Bonjour !")

    post contact_chat_path, params: { message: "Bonjour" }

    assert_requested :post, MAMMOUTH_URL do |req|
      req.headers["Authorization"].start_with?("Bearer ") &&
        JSON.parse(req.body)["model"] == "gemini-3.5-flash"
    end
  end
end
