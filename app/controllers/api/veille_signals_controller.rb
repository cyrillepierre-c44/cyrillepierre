module Api
  # Reçoit les signaux de la routine de veille. Pas de session, pas de CSRF : un jeton partagé
  # (`VEILLE_API_TOKEN`, posé sur Heroku et dans l'environnement cloud de la routine) dans
  # l'en-tête Authorization. Idempotent par (semaine, lien source) : la routine peut renvoyer
  # le même lot sans doublonner, et un lien déjà connu met la fiche à jour.
  class VeilleSignalsController < ActionController::API
    before_action :authenticate_token!

    PERMITTED = %i[rank shortlisted company location sector signal_type signal source_name source_url
                   published_on why_now comparable pitch].freeze

    def create
      week = Date.iso8601(params.require(:week))
      results = Array(params.require(:signals)).map { |raw| upsert(week, raw) }
      created = results.count(&:previously_new_record?)
      render json: { week: week, received: results.size, created: created, updated: results.size - created,
                     validate_at: studio_veille_signals_url }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
    rescue ActionController::ParameterMissing, Date::Error => e
      render json: { error: e.message }, status: :bad_request
    end

    private

    def upsert(week, raw)
      attributes = raw.permit(*PERMITTED).to_h
      signal = VeilleSignal.find_or_initialize_by(run_week: week, source_url: attributes["source_url"])
      # Un signal déjà tranché par Cyrille ne redevient pas « à valider » parce que la routine l'a revu.
      signal.assign_attributes(attributes.except("source_url")) if signal.pending? || signal.new_record?
      signal.save!
      signal
    end

    def authenticate_token!
      expected = ENV.fetch("VEILLE_API_TOKEN", nil)
      provided = request.authorization.to_s.delete_prefix("Bearer ").strip
      return if expected.present? && ActiveSupport::SecurityUtils.secure_compare(provided, expected)

      render json: { error: "jeton absent ou invalide" }, status: :unauthorized
    end
  end
end
