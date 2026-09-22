# Trois recherches web et une lecture par le modèle : en tâche de fond, la fiche annonce
# l'attente puis affiche les noms trouvés ; un échec s'écrit dans la fiche.
class DecisionMakerSearchJob < ApplicationJob
  queue_as :default

  def perform(prospect)
    prospect.update!(contacts_research: DecisionMakerFinder.call(prospect), contacts_researched_at: Time.current)
  rescue StandardError => e
    prospect.update!(contacts_research: "Recherche impossible : #{e.class} — #{e.message.truncate(200)}",
                     contacts_researched_at: Time.current)
  end
end
