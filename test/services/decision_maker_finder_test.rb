require "test_helper"

# Le modèle propose des noms, Ruby ne garde que ceux dont la phrase citée est mot pour mot
# dans la page citée : un nom inventé, une citation reformulée ou une source inconnue tombent.
# Chaque nom sort avec la date de sa page (écrite dans la page ou portée par l'adresse), et une
# page de plus de deux ans ne compte plus parmi les probables.
class DecisionMakerFinderTest < ActiveSupport::TestCase
  Reply = Struct.new(:content)

  class FakeChat
    attr_reader :question

    def initialize(reply) = @reply = reply
    def with_instructions(_) = self

    def ask(question)
      @question = question
      Reply.new(@reply)
    end
  end

  class FakeContext
    attr_reader :chat_double

    def initialize(reply) = @chat_double = FakeChat.new(reply)
    def chat(**) = @chat_double
  end

  ARTICLE = "Publié le 12 février 2026. Inauguration de l'extension : « Nous avons doublé la capacité », se félicite " \
            "Jean Martin, directeur de l'usine MAPEI de Saint-Vulbas. Le maire, Pierre Durand, salue l'investissement."

  setup do
    @key = ENV["TAVILY_API_KEY"]
    ENV["TAVILY_API_KEY"] = "tvly-test"
    user = User.create!(email: "dm-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @prospect = Prospect.create!(user: user, name: "Décideur à identifier", company: "MAPEI France — usine de Saint-Vulbas (01)")
    stub_request(:post, Tavily::SEARCH_URL).to_return(
      status: 200,
      body: { results: [{ title: "Le Progrès", url: "https://example.com/inauguration", content: "extrait", raw_content: ARTICLE },
                        { title: "Profil", url: "https://example.com/profil", content: "Sophie Bernard - Directrice de site chez MAPEI - Saint-Vulbas" }] }.to_json
    )
  end

  teardown { ENV["TAVILY_API_KEY"] = @key }

  def with_reply(reply)
    RubyLLM.stub(:context, FakeContext.new(reply), Struct.new(:openai_api_key, :openai_api_base).new) { yield }
  end

  # Le modèle reçoit la consigne de dater la page : la clé figure dans ses instructions.
  def context_question_of(_reply)
    DecisionMakerFinder::INSTRUCTIONS
  end

  test "keeps only the names whose exact quote is in the cited page, and says what was dropped" do
    reply = [
      { name: "Jean Martin", title: "directeur de l'usine", source: "https://example.com/inauguration",
        quote: "se félicite Jean Martin, directeur de l'usine MAPEI de Saint-Vulbas", date: "2026-02-12" },
      { name: "Sophie Bernard", title: "Directrice de site", source: "https://example.com/profil",
        quote: "Sophie Bernard - Directrice de site chez MAPEI", date: "2026-09-01" },
      { name: "Paul Invente", title: "directeur", source: "https://example.com/inauguration", quote: "Paul Invente dirige le site" },
      { name: "Jean Martin", title: "directeur", source: "https://example.com/ailleurs", quote: "Jean Martin" },
      { name: "Pierre Durand", title: "directeur", source: "https://example.com/inauguration", quote: "Le maire, Pierre Durand, salue l'investissement" }
    ].to_json

    text = with_reply(reply) { DecisionMakerFinder.call(@prospect) }

    assert_includes text, "DÉCIDEURS PROBABLES (recherche web Tavily, 3 requêtes, 2 pages lues) :"
    assert_includes text, "- Jean Martin — directeur de l'usine — https://example.com/inauguration — source du 12/02/2026\n" \
                          "  « se félicite Jean Martin"
    assert_includes text, "- Sophie Bernard — Directrice de site — https://example.com/profil — page non datée, vérifier d'abord"
    assert_includes text, "- Pierre Durand — directeur — https://example.com/inauguration — source du 12/02/2026"
    assert_operator text.index("Jean Martin"), :<, text.index("Sophie Bernard"), "dated pages come first"
    assert_not_includes text, "TROP ANCIENS"
    assert_not_includes text, "Paul Invente"
    assert_includes text, "(2 proposition(s) écartée(s) faute de citation exacte.)"
    assert_includes text, "À vérifier sur LinkedIn"
    assert_includes text, "Pages consultées : https://example.com/inauguration · https://example.com/profil"
  end

  test "the model reads the company, the town and every page, and an empty or broken answer yields no name" do
    context = FakeContext.new("pas du json")
    text = RubyLLM.stub(:context, context, Struct.new(:openai_api_key, :openai_api_base).new) { DecisionMakerFinder.call(@prospect) }

    assert_includes context.chat_double.question, "ENTREPRISE : MAPEI France — site de Saint-Vulbas"
    assert_includes context.chat_double.question, "SOURCE 1 — https://example.com/inauguration\nextrait\n#{ARTICLE}"
    assert_includes text, "- Aucun nom vérifiable dans une page récente."

    text = with_reply("[]") { DecisionMakerFinder.call(@prospect) }
    assert_includes text, "Aucun nom vérifiable"
  end

  test "a name from a page older than two years is set apart, dated from the page or from its address" do
    travel_to Time.zone.local(2026, 9, 23, 12) do
      stub_request(:post, Tavily::SEARCH_URL).to_return(
        status: 200,
        body: { results: [
          { title: "Batiactu", url: "https://example.com/troisieme-usine", content: "extrait",
            raw_content: "24/11/2015 — « C'est notre troisième usine », souligne Yannick Lagarde, Directeur Industriel MAPEI France." },
          { title: "Gazette", url: "https://example.com/article/mapei-SAINT-VULBAS-21102024", content: "extrait",
            raw_content: "MAPEI renforce son implantation, annonce Claire Petit, directrice du site de Saint-Vulbas." },
          { title: "Récent", url: "https://example.com/recent", content: "extrait",
            raw_content: "Le 3 septembre 2026, Marc Roux, directeur d'usine, a reçu la préfète." }
        ] }.to_json
      )
      reply = [
        { name: "Yannick Lagarde", title: "Directeur Industriel MAPEI France", source: "https://example.com/troisieme-usine",
          quote: "souligne Yannick Lagarde, Directeur Industriel MAPEI France", date: "2015-11-24" },
        { name: "Claire Petit", title: "directrice du site", source: "https://example.com/article/mapei-SAINT-VULBAS-21102024",
          quote: "annonce Claire Petit, directrice du site de Saint-Vulbas", date: nil },
        { name: "Marc Roux", title: "directeur d'usine", source: "https://example.com/recent",
          quote: "Marc Roux, directeur d'usine", date: "2019-01-01" }
      ].to_json

      text = with_reply(reply) { DecisionMakerFinder.call(@prospect) }

      assert_includes text, "- Marc Roux — directeur d'usine — https://example.com/recent — page non datée, vérifier d'abord de quand elle date",
                      "a date the page does not show is not trusted"
      assert_includes text, "- Claire Petit — directrice du site — https://example.com/article/mapei-SAINT-VULBAS-21102024 — source du 21/10/2024 (il y a 1 an)"
      assert_includes text, "TROP ANCIENS pour dire qui est en poste aujourd'hui (source de plus de deux ans) :\n" \
                            "- Yannick Lagarde — Directeur Industriel MAPEI France — https://example.com/troisieme-usine — source du 24/11/2015 (il y a 10 ans)"
      assert_operator text.index("Claire Petit"), :<, text.index("Marc Roux"), "dated pages come first"
      assert_operator text.index("Marc Roux"), :<, text.index("TROP ANCIENS")
      assert_includes text, "une page datée dit qui était en poste ce jour-là, pas aujourd'hui"
      assert_includes context_question_of(reply), '"date"'
    end
  end

  test "no page at all is said plainly, without calling the model" do
    stub_request(:post, Tavily::SEARCH_URL).to_return(status: 200, body: { results: [] }.to_json)

    text = DecisionMakerFinder.call(@prospect)

    assert_equal "Aucune page trouvée par la recherche web pour « MAPEI France Saint-Vulbas ».", text
  end
end
