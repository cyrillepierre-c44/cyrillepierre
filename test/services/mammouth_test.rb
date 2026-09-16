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

  test "the context points RubyLLM at the Mammouth gateway with the key from the environment" do
    config = Struct.new(:openai_api_key, :openai_api_base).new
    RubyLLM.stub(:context, :context_double, config) { assert_equal :context_double, Mammouth.context }

    assert_equal Mammouth::API_BASE, config.openai_api_base
    assert_equal Mammouth.api_key, config.openai_api_key
  end
end
