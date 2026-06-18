# Handles the OAuth2 dance that lets a Studio user connect their LinkedIn account, so
# LinkedinPublisher can later post on their behalf (see app/services/linkedin_publisher.rb).
class LinkedinAuthController < ApplicationController
  before_action :authenticate_user!

  AUTHORIZE_URL = "https://www.linkedin.com/oauth/v2/authorization"
  TOKEN_URL = "https://www.linkedin.com/oauth/v2/accessToken"
  USERINFO_URL = "https://api.linkedin.com/v2/userinfo"
  SCOPE = "openid profile w_member_social"

  def connect
    state = SecureRandom.hex(16)
    session[:linkedin_oauth_state] = state

    redirect_to "#{AUTHORIZE_URL}?#{authorize_params(state)}", allow_other_host: true
  end

  def callback
    return if callback_rejected?

    store_credentials(exchange_code_for_token(params[:code]))
    redirect_to studio_generations_path, notice: "Compte LinkedIn connecté."
  rescue Faraday::Error, KeyError => e
    Rails.logger.error "LinkedinAuthController callback error: #{e.class} — #{e.message}"
    redirect_to studio_generations_path, alert: "Impossible de connecter le compte LinkedIn."
  end

  def disconnect
    current_user.update!(linkedin_access_token: nil, linkedin_token_expires_at: nil, linkedin_member_urn: nil)
    redirect_to studio_generations_path, notice: "Compte LinkedIn déconnecté."
  end

  private

  # Returns true (and redirects) when the callback shouldn't proceed: the user denied access,
  # or the state doesn't match what /connect stored (missing/forged/expired session).
  def callback_rejected?
    if params[:error].present?
      redirect_to studio_generations_path, alert: "Connexion LinkedIn annulée."
      return true
    end

    state = session.delete(:linkedin_oauth_state)
    return false if state.present? && state == params[:state]

    redirect_to studio_generations_path, alert: "Connexion LinkedIn invalide, réessaie."
    true
  end

  def store_credentials(token_data)
    current_user.update!(
      linkedin_access_token: token_data["access_token"],
      linkedin_token_expires_at: Time.current + token_data["expires_in"].to_i.seconds,
      linkedin_member_urn: fetch_member_urn(token_data["access_token"])
    )
  end

  def authorize_params(state)
    {
      response_type: "code",
      client_id: ENV.fetch("LINKEDIN_CLIENT_ID", nil),
      redirect_uri: linkedin_auth_callback_url,
      scope: SCOPE,
      state: state
    }.to_query
  end

  def token_exchange_params(code)
    {
      grant_type: "authorization_code",
      code: code,
      redirect_uri: linkedin_auth_callback_url,
      client_id: ENV.fetch("LINKEDIN_CLIENT_ID", nil),
      client_secret: ENV.fetch("LINKEDIN_CLIENT_SECRET", nil)
    }
  end

  def exchange_code_for_token(code)
    response = Faraday.post(TOKEN_URL, token_exchange_params(code),
                            "Content-Type" => "application/x-www-form-urlencoded")

    JSON.parse(response.body)
  end

  def fetch_member_urn(access_token)
    response = Faraday.get(USERINFO_URL) do |req|
      req.headers["Authorization"] = "Bearer #{access_token}"
    end

    JSON.parse(response.body).fetch("sub")
  end
end
