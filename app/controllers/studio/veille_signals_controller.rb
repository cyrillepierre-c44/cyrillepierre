module Studio
  # Le lundi matin : les signaux de la routine, à retenir (une fiche prospect naît, remplie) ou
  # à écarter. Rien n'est ressaisi.
  class VeilleSignalsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_signal, only: %i[keep dismiss]

    def index
      authorize VeilleSignal
      scope = policy_scope(VeilleSignal)
      # Les annonces trop jeunes passent en fin de semaine : elles ne sont pas encore un signal.
      # Les annonces trop jeunes et les entreprises déjà tranchées passent en fin de semaine.
      @pending = scope.pending.order(run_week: :desc).shortlist_first.to_a
                      .sort_by.with_index { |s, i| [-s.run_week.jd, s.too_young? || s.previous_decision ? 1 : 0, i] }
      @decisions = policy_scope(VeilleDecision).recent_first.includes(:prospect).limit(40)
    end

    def keep
      prospect = @signal.keep!(current_user, reason: params[:reason])
      redirect_to studio_veille_signals_path, notice: "Fiche prospect créée : #{prospect.company}."
    end

    def dismiss
      @signal.dismiss!(current_user, reason: params[:reason])
      redirect_to studio_veille_signals_path, notice: "Signal écarté."
    end

    private

    def set_signal
      @signal = policy_scope(VeilleSignal).pending.find(params[:id])
      authorize @signal
    end
  end
end
