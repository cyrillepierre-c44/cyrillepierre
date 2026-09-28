module Api
  # La mémoire de tri, lue par la routine du lundi avant toute recherche (même jeton que les
  # dépôts). Texte brut : c'est un morceau de prompt, pas une API à parcourir.
  class VeilleMemoryController < ActionController::API
    include TokenAuthentication

    def show
      render plain: VeilleDecision.to_prompt
    end
  end
end
