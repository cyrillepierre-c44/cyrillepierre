module Studio
  class GenerationsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_generation,
                  only: %i[show edit update destroy regenerate publish unpublish generate_visual publish_to_linkedin
                           document pdf send_email mark_sent]

    def index
      @generations = policy_scope(Generation).order(updated_at: :desc)
    end

    def new
      # Depuis une fiche prospect, le brief est pré-rempli côté serveur à partir de `prospect_id`
      # (voir Prospect#brief_for_proposal) : le besoin a déjà été qualifié, le retaper serait absurde.
      # Le brief ne passe plus dans l'adresse — une fiche fournie dépasse la taille d'URL acceptée
      # par Heroku (400), et des données de prospect n'ont rien à faire dans des journaux d'accès.
      # `title`/`input_text` restent acceptés pour les liens simples.
      @generation = Generation.new(kind: params[:kind], title: params[:title], input_text: params[:input_text],
                                   source_article_id: params[:source_article_id])
      prefill_from_prospect if params[:prospect_id].present?
      authorize @generation
    end

    def create
      @generation = current_user.generations.new(generation_params)
      authorize @generation
      ensure_prospect_in_scope!

      if @generation.save
        enqueue_generation(with_visual: generate_visual_requested?)
        redirect_to studio_generation_path(@generation), notice: "Génération lancée."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
    end

    def edit
    end

    def update
      if @generation.update(generation_params)
        redirect_to studio_generation_path(@generation), notice: update_notice
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @generation.destroy
      redirect_to studio_generations_path, notice: "Génération supprimée."
    end

    def regenerate
      @generation.update!(llm_model: generation_params[:llm_model]) if generation_params[:llm_model].present?
      enqueue_generation
      redirect_to studio_generation_path(@generation), notice: "Régénération lancée."
    end

    # L'email part depuis contact@ (MailDeliveryJob, avec ses reprises réseau) et la fiche prospect
    # devient le journal du contact. Le message LinkedIn se copie et s'envoie à la main : aucune API
    # de messagerie à ce niveau d'accès, d'où « Marquer envoyé ».
    def send_email
      unless @generation.email_sendable?
        return redirect_to studio_generation_path(@generation),
                           alert: "Pas d'envoi possible : il faut un message généré et une adresse email sur la fiche."
      end

      OutreachMailer.first_contact(@generation).deliver_later
      @generation.mark_sent!("email")
      redirect_to studio_generation_path(@generation), notice: "Message envoyé à #{@generation.prospect.email}."
    end

    def mark_sent
      unless @generation.outreach_message? && @generation.prospect
        return redirect_to studio_generation_path(@generation),
                           alert: "Ce contenu n'est pas un message lié à une fiche."
      end

      @generation.mark_sent!("linkedin")
      redirect_to studio_generation_path(@generation), notice: "Envoi LinkedIn noté sur la fiche prospect."
    end

    def publish
      @generation.update!(status: :published, published_at: Time.current)
      redirect_to studio_generation_path(@generation), notice: "Publié sur /actus."
    end

    def unpublish
      @generation.update!(status: :generated, published_at: nil)
      redirect_to studio_generation_path(@generation), notice: "Dépublié."
    end

    def generate_visual
      image_model = params.dig(:generation, :image_model)
      @generation.update!(image_model: image_model) if image_model.present?
      VisualGenerator.call(@generation)
      redirect_to studio_generation_path(@generation), notice: "Visuel généré."
    end

    # La note de diagnostic, en page autonome aux couleurs du site, à imprimer en PDF depuis le
    # navigateur. Sans layout : la page doit tenir seule, sans navigation ni pied de page du Studio.
    def document
      ensure_printable!
      render layout: false
    end

    # Le même document, paginé en A4 côté serveur : sur téléphone, l'impression du navigateur ne
    # donnait qu'un long ruban.
    def pdf
      ensure_printable!
      send_data ExecutiveBriefPdf.call(@generation), filename: pdf_filename, type: "application/pdf",
                                                     disposition: "attachment"
    end

    def publish_to_linkedin
      LinkedinPublisher.call(@generation)
      redirect_to studio_generation_path(@generation), notice: "Publié sur LinkedIn."
    rescue LinkedinPublisher::Error => e
      redirect_to studio_generation_path(@generation), alert: e.message
    end

    private

    def ensure_printable!
      raise ActiveRecord::RecordNotFound unless @generation.executive_brief? && @generation.output.present?
    end

    def pdf_filename
      "#{@generation.display_title.parameterize.presence || 'note-de-diagnostic'}.pdf"
    end

    def prefill_from_prospect
      prospect = policy_scope(Prospect).find(params[:prospect_id])
      @generation.prospect = prospect
      @generation.input_text = prospect.brief_for_proposal
      @generation.title ||= default_title_for(prospect)
    end

    def default_title_for(prospect)
      prefix = if @generation.executive_brief? then "Note de diagnostic"
               elsif @generation.outreach_message? then "Premier contact"
               else "Proposition"
               end
      "#{prefix} — #{prospect.display_company}"
    end

    # Le prospect arrive par un champ caché : il doit être dans le périmètre de l'utilisateur,
    # sinon un identifiant deviné rattacherait un message à la fiche d'un autre.
    def ensure_prospect_in_scope!
      id = generation_params[:prospect_id]
      return if id.blank? || policy_scope(Prospect).exists?(id)

      raise ActiveRecord::RecordNotFound
    end

    # `generating_since` est posé ici, pas dans la tâche : la page de destination doit déjà
    # annoncer l'attente, même si la file met une seconde à démarrer.
    def enqueue_generation(with_visual: false)
      @generation.update!(generating_since: Time.current)
      ContentGenerationJob.perform_later(@generation, with_visual: with_visual)
    end

    # Une source modifiée ne change rien tant que le texte n'est pas régénéré : le dire au moment
    # où l'on vient de coller une analyse, plutôt que de laisser croire que la note en tient compte.
    def update_notice
      return "Mis à jour." unless @generation.saved_change_to_financial_analysis? ||
                                  @generation.saved_change_to_input_text?

      "Source mise à jour — lance « Régénérer » pour un texte qui en tienne compte."
    end

    def set_generation
      @generation = policy_scope(Generation).find(params[:id])
      authorize @generation
    end

    def generation_params
      params.require(:generation).permit(
        :kind, :title, :input_text, :input_url, :extra_instructions, :source_file, :llm_model, :orientation,
        :realisation_id, :output, :generate_visual, :image_model, :source_article_id, :financial_analysis,
        :prospect_id
      )
    end

    def generate_visual_requested?
      ActiveModel::Type::Boolean.new.cast(generation_params[:generate_visual])
    end
  end
end
