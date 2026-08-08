# Rate limiting. The contact form's chatbot endpoints each trigger a paid Mammouth API call,
# so an unthrottled loop is a billing problem before it is a security one.
class Rack::Attack
  # Endpoints that cost money on every hit.
  LLM_PATHS = %w[/contact/chat /contact/summarize /contact/infer_company].freeze

  throttle("llm/ip", limit: 20, period: 1.minute) do |request|
    request.ip if LLM_PATHS.include?(request.path)
  end

  throttle("llm/ip/hourly", limit: 120, period: 1.hour) do |request|
    request.ip if LLM_PATHS.include?(request.path)
  end

  # Contact form submissions send two emails each.
  throttle("contact/ip", limit: 5, period: 1.hour) do |request|
    request.ip if request.post? && request.path == "/contact"
  end

  # Devise sign-in: slows down credential stuffing on the Studio.
  throttle("login/ip", limit: 10, period: 20.minutes) do |request|
    request.ip if request.post? && request.path == "/users/sign_in"
  end

  # Global backstop against a crawler hammering the whole site. Static assets are exempt so a
  # normal page load (stylesheet + importmap + fonts) never counts against a visitor.
  throttle("req/ip", limit: 300, period: 5.minutes) do |request|
    request.ip unless request.path.start_with?("/assets", "/images", "/up")
  end

  self.throttled_responder = lambda do |request|
    retry_after = (request.env["rack.attack.match_data"] || {})[:period].to_i
    [ 429,
      { "content-type" => "text/plain", "retry-after" => retry_after.to_s },
      ["Trop de requêtes. Merci de patienter un instant.\n"] ]
  end
end
