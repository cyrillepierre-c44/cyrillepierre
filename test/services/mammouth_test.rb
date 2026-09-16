require "test_helper"

# Le module ne fait que porter l'adresse, la clé et le modèle par défaut, et construire le
# contexte RubyLLM : on vérifie que tout le monde lit bien au même endroit.
class MammouthTest < ActiveSupport::TestCase
  test "the default model is the one the Studio and the contact assistant fall back on" do
    assert_equal Mammouth::DEFAULT_MODEL, Generation::DEFAULT_LLM_MODEL
    assert_equal Mammouth::DEFAULT_MODEL, ContentGenerator::PROOFREADING_MODEL
    assert_includes Generation::LLM_MODELS.keys, Mammouth::DEFAULT_MODEL
  end

  test "the chat completions endpoint hangs off the API base" do
    assert Mammouth::CHAT_COMPLETIONS_URL.start_with?(Mammouth::API_BASE)
  end

  # La clé est posée explicitement : en CI la variable n'existe pas, et comparer deux nil ne
  # prouverait rien (Minitest le refuse d'ailleurs). Chaque worker de test est un processus,
  # la modification d'ENV ne fuit pas vers les autres.
  test "the context points RubyLLM at the Mammouth gateway with the key from the environment" do
    original = ENV.fetch("MAMMOUTH_API_KEY", nil)
    ENV["MAMMOUTH_API_KEY"] = "cle-de-test"
    config = Struct.new(:openai_api_key, :openai_api_base).new
    RubyLLM.stub(:context, :context_double, config) { assert_equal :context_double, Mammouth.context }

    assert_equal Mammouth::API_BASE, config.openai_api_base
    assert_equal "cle-de-test", config.openai_api_key
  ensure
    ENV["MAMMOUTH_API_KEY"] = original
  end
end
