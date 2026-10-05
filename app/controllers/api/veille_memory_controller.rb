module Api
  # La mémoire de tri, lue par la routine du lundi avant toute recherche (même jeton que les
  # dépôts). Texte brut : c'est un morceau de prompt, pas une API à parcourir. Les décisions, puis
  # les fiches en cours — une entreprise suivie sans décision enregistrée y était invisible.
  class VeilleMemoryController < ActionController::API
    include TokenAuthentication

    def show
      render plain: [VeilleDecision.to_prompt, Prospect.pipeline_prompt].join("\n\n")
    end
  end
end
