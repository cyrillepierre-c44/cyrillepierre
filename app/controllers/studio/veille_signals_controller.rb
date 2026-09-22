module Studio
  # Le lundi matin : les signaux de la routine, à retenir (une fiche prospect naît, remplie) ou
  # à écarter. Rien n'est ressaisi.
  class VeilleSignalsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_signal, only: %i[keep dismiss]

    def index
      authorize VeilleSignal
      scope = policy_scope(VeilleSignal)
      @pending = scope.pending.order(run_week: :desc).shortlist_first
      @recent = scope.where.not(status: :pending).where(updated_at: 4.weeks.ago..).order(updated_at: :desc)
    end

    def keep
      prospect = @signal.keep!(current_user)
      redirect_to studio_veille_signals_path, notice: "Fiche prospect créée : #{prospect.company}."
    end

    def dismiss
      @signal.dismiss!
      redirect_to studio_veille_signals_path, notice: "Signal écarté."
    end

    private

    def set_signal
      @signal = policy_scope(VeilleSignal).pending.find(params[:id])
      authorize @signal
    end
  end
end
