module Studio
  # Une raison se corrige après coup, sur /studio/veille : la mémoire doit rester juste, la
  # routine la lit telle quelle.
  class VeilleDecisionsController < ApplicationController
    before_action :authenticate_user!

    def update
      decision = policy_scope(VeilleDecision).find(params[:id])
      authorize decision
      decision.update!(reason: params.require(:veille_decision).fetch(:reason, "").presence)
      redirect_to studio_veille_signals_path, notice: "Raison enregistrée."
    end
  end
end
