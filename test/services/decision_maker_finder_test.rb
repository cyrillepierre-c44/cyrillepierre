require "test_helper"

# Le modèle propose des noms, Ruby ne garde que ceux dont la phrase citée est mot pour mot
# dans la page citée : un nom inventé, une citation reformulée ou une source inconnue tombent.
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

  ARTICLE = "Inauguration de l'extension : « Nous avons doublé la capacité », se félicite Jean Martin, directeur " \
            "de l'usine MAPEI de Saint-Vulbas. Le maire, Pierre Durand, salue l'investissement."

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

  test "keeps only the names whose exact quote is in the cited page, and says what was dropped" do
    reply = [
      { name: "Jean Martin", title: "directeur de l'usine", source: "https://example.com/inauguration",
        quote: "se félicite Jean Martin, directeur de l'usine MAPEI de Saint-Vulbas" },
      { name: "Sophie Bernard", title: "Directrice de site", source: "https://example.com/profil",
        quote: "Sophie Bernard - Directrice de site chez MAPEI" },
      { name: "Paul Invente", title: "directeur", source: "https://example.com/inauguration", quote: "Paul Invente dirige le site" },
      { name: "Jean Martin", title: "directeur", source: "https://example.com/ailleurs", quote: "Jean Martin" },
      { name: "Pierre Durand", title: "directeur", source: "https://example.com/inauguration", quote: "Le maire, Pierre Durand, salue l'investissement" }
    ].to_json

    text = with_reply(reply) { DecisionMakerFinder.call(@prospect) }

    assert_includes text, "DÉCIDEURS PROBABLES (recherche web Tavily, 3 requêtes, 2 pages lues) :"
    assert_includes text, "- Jean Martin — directeur de l'usine — https://example.com/inauguration\n  « se félicite Jean Martin"
    assert_includes text, "- Sophie Bernard — Directrice de site — https://example.com/profil"
    assert_includes text, "- Pierre Durand — directeur"
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
    assert_includes text, "- Aucun nom vérifiable dans les pages lues."

    text = with_reply("[]") { DecisionMakerFinder.call(@prospect) }
    assert_includes text, "Aucun nom vérifiable"
  end

  test "no page at all is said plainly, without calling the model" do
    stub_request(:post, Tavily::SEARCH_URL).to_return(status: 200, body: { results: [] }.to_json)

    text = DecisionMakerFinder.call(@prospect)

    assert_equal "Aucune page trouvée par la recherche web pour « MAPEI France Saint-Vulbas ».", text
  end
end
