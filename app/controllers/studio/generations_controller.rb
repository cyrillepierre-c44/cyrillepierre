module Studio
  class GenerationsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_generation, only: %i[show edit update destroy regenerate publish unpublish]

    def index
      @generations = policy_scope(Generation).order(updated_at: :desc)
    end

    def new
      @generation = Generation.new(kind: params[:kind])
      authorize @generation
    end

    def create
      @generation = current_user.generations.new(generation_params)
      authorize @generation

      if @generation.save
        ContentGenerator.call(@generation)
        redirect_to studio_generation_path(@generation), notice: "Contenu généré."
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
        redirect_to studio_generation_path(@generation), notice: "Mis à jour."
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
      ContentGenerator.call(@generation)
      redirect_to studio_generation_path(@generation), notice: "Contenu régénéré."
    end

    def publish
      @generation.update!(status: :published, published_at: Time.current)
      redirect_to studio_generation_path(@generation), notice: "Publié sur /actus."
    end

    def unpublish
      @generation.update!(status: :generated, published_at: nil)
      redirect_to studio_generation_path(@generation), notice: "Dépublié."
    end

    private

    def set_generation
      @generation = policy_scope(Generation).find(params[:id])
      authorize @generation
    end

    def generation_params
      params.require(:generation).permit(
        :kind, :title, :input_text, :input_url, :extra_instructions, :source_file, :llm_model
      )
    end
  end
end
