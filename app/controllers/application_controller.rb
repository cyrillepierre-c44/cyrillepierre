class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Garantit qu'aucune action du Studio ne passe sans contrôle d'autorisation. Un seul callback
  # sans `only:`/`except:` qui dispatche sur `action_name` : la variante
  # `except: :index` + `only: :index` casse dès qu'un controller n'a pas d'action `index`
  # (`raise_on_missing_callback_actions` est actif en test).
  after_action :verify_pundit_authorization, unless: :skip_pundit?

  private

  def verify_pundit_authorization
    action_name == "index" ? verify_policy_scoped : verify_authorized
  end

  # Seul le Studio est protégé par Pundit : les pages publiques (accueil, réalisations, CV,
  # contact, actus) et les controllers Devise n'ont rien à autoriser.
  def skip_pundit?
    devise_controller? || !controller_path.start_with?("studio/")
  end

  def user_not_authorized
    redirect_back fallback_location: root_path, alert: "Vous n'êtes pas autorisé à effectuer cette action."
  end
end
