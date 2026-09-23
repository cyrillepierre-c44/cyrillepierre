module Api
  # Reçoit le brief de la routine « Brief article hebdo » et en fait un brouillon d'article dans le
  # Studio, rattaché au premier administrateur : le mail du lundi ne portait qu'un texte, et Cyrille
  # cherchait l'article sur le site sans le trouver (23/09/2026). Le brouillon attend son clic sur
  # « Générer ». Idempotent par titre : renvoyer le même brief ne crée pas deux brouillons vides.
  class ArticleBriefsController < ActionController::API
    include TokenAuthentication

    def create
      title = params.require(:title).to_s.strip
      brief = params.require(:brief).to_s.strip
      generation = existing_draft(title) ||
                   owner.generations.create!(kind: :article, status: :draft, title: title, input_text: brief)
      render json: { id: generation.id, created: generation.previously_new_record?,
                     studio_url: studio_generation_url(generation) }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
    rescue ActionController::ParameterMissing => e
      render json: { error: e.message }, status: :bad_request
    end

    private

    def owner
      User.admin.order(:id).first or raise ActiveRecord::RecordInvalid, Generation.new
    end

    def existing_draft(title)
      Generation.where(kind: :article, status: :draft, title: title, output: [nil, ""]).order(:id).first
    end
  end
end
