# Le seul fournisseur LLM du site, derrière une passerelle compatible OpenAI. Adresse, clé et
# modèle par défaut vivaient à quatre endroits (initialiseur, générateur de texte, générateur de
# visuel, assistant de contact) : ici et nulle part ailleurs.
module Mammouth
  API_BASE = "https://api.mammouth.ai/v1".freeze
  CHAT_COMPLETIONS_URL = "#{API_BASE}/chat/completions".freeze

  # Gemini 3.5 Flash : rapide et peu cher, c'est le modèle de tout ce qui n'a pas de raison
  # d'en choisir un autre (relecture, assistant de contact, brouillon par défaut du Studio).
  DEFAULT_MODEL = "gemini-3.5-flash".freeze

  # Les appels RubyLLM passent tous par ce contexte plutôt que par la configuration globale :
  # les tests le doublent en substituant `RubyLLM.context`, un point d'entrée unique.
  def self.context
    RubyLLM.context do |config|
      config.openai_api_key = api_key
      config.openai_api_base = API_BASE
    end
  end

  def self.chat(model:)
    context.chat(model: model, provider: :openai, assume_model_exists: true)
  end

  def self.paint(prompt, model:)
    context.paint(prompt, model: model, provider: :openai, assume_model_exists: true)
  end

  def self.api_key
    ENV.fetch("MAMMOUTH_API_KEY", nil)
  end
end
