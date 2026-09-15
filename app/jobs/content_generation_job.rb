# La génération dure de vingt à quarante secondes selon le modèle et la longueur du prompt, alors
# qu'Heroku coupe toute requête web à trente. Elle se faisait dans la requête : le Studio rendait
# donc une page d'erreur sur les contenus les plus longs, exactement ceux qui comptent.
class ContentGenerationJob < ApplicationJob
  queue_as :default

  def perform(generation, with_visual: false)
    ContentGenerator.call(generation)
    VisualGenerator.call(generation) if with_visual
  ensure
    # Quoi qu'il arrive, la page cesse d'annoncer une génération en cours : une erreur laisserait
    # sinon l'utilisateur devant une attente sans fin.
    generation.update_columns(generating_since: nil)
  end
end
