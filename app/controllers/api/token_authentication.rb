module Api
  # Les routines cloud n'ont ni session ni CSRF : un jeton partagé (`VEILLE_API_TOKEN`, posé sur
  # Heroku et dans l'environnement cloud « Veille ») dans l'en-tête Authorization, comparé en
  # temps constant. Le même jeton sert à toutes les routines qui déposent dans le Studio.
  module TokenAuthentication
    extend ActiveSupport::Concern

    included do
      before_action :authenticate_token!
    end

    private

    def authenticate_token!
      expected = ENV.fetch("VEILLE_API_TOKEN", nil)
      provided = request.authorization.to_s.delete_prefix("Bearer ").strip
      return if expected.present? && ActiveSupport::SecurityUtils.secure_compare(provided, expected)

      render json: { error: "jeton absent ou invalide" }, status: :unauthorized
    end
  end
end
