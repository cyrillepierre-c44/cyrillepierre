# Trois appels réseau qui peuvent traîner : en tâche de fond, la fiche affiche « en cours » puis le
# résultat. Un échec est écrit dans la fiche plutôt que perdu dans un journal.
class ProspectEnrichmentJob < ApplicationJob
  queue_as :default

  def perform(prospect)
    result = ProspectEnricher.call(prospect)
    prospect.update!(enrichment: result.text, siren: result.siren || prospect.siren, enriched_at: Time.current)
  rescue StandardError => e
    prospect.update!(enrichment: "Enrichissement impossible : #{e.class} — #{e.message.truncate(200)}",
                     enriched_at: Time.current)
  end
end
