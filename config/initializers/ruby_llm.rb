# Configuration globale de RubyLLM, alignée sur le module Mammouth (app/services/mammouth.rb),
# par lequel passent tous les appels des services. Un initialiseur s'exécute avant le chargement
# automatique de app/ : d'où le `to_prepare`, qui attend que les constantes soient visibles.
Rails.application.config.to_prepare do
  RubyLLM.configure do |config|
    config.openai_api_key = Mammouth.api_key
    config.openai_api_base = Mammouth::API_BASE
  end
end
