module Studio
  class ProspectsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_prospect, only: %i[show edit update destroy]

    def index
      scope = policy_scope(Prospect)
      @status_filter = params[:status].presence_in(Prospect::STATUSES.keys.map(&:to_s))
      @relances = scope.ouverts.en_retard.pipeline_order
      @prospects = (@status_filter ? scope.where(status: @status_filter) : scope).pipeline_order
      @counts = scope.group(:status).count
    end

    def show
    end

    def new
      @prospect = Prospect.new(status: :a_contacter, source: :reseau)
      authorize @prospect
    end

    def create
      @prospect = current_user.prospects.new(prospect_params)
      authorize @prospect

      if @prospect.save
        redirect_to studio_prospect_path(@prospect), notice: "Prospect créé."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @prospect.update(prospect_params)
        redirect_to studio_prospect_path(@prospect), notice: "Prospect mis à jour."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @prospect.destroy
      redirect_to studio_prospects_path, notice: "Prospect supprimé."
    end

    private

    def set_prospect
      @prospect = policy_scope(Prospect).find(params[:id])
      authorize @prospect
    end

    def prospect_params
      params.require(:prospect).permit(
        :name, :email, :company, :phone, :sector, :company_size, :source, :status, :themes_text,
        :summary, :conversation, :visitor_precision, :notes, :last_contact_at, :next_action, :next_action_on
      )
    end
  end
end
