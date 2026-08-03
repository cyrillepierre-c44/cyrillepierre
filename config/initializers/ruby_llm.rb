RubyLLM.configure do |config|
  # Mammouth.ai (OpenAI-compatible gateway) is the app's only LLM provider —
  # the former GitHub Models free tier expired and was removed.
  config.openai_api_key = ENV.fetch("MAMMOUTH_API_KEY", nil)
  config.openai_api_base = "https://api.mammouth.ai/v1"
end
