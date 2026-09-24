# Applique la durée de conservation annoncée dans /politique-de-confidentialite. Sans ce job,
# la page promettrait une suppression qui n'arriverait jamais.
#
# Planifié dans config/recurring.yml (production uniquement). Solid Queue tourne dans le
# process Puma via SOLID_QUEUE_IN_PUMA : sans cette variable sur Heroku, rien ne s'exécute.
class ProspectPurgeJob < ApplicationJob
  queue_as :default

  def perform
    purge_signals
    expired = Prospect.expired
    count = expired.count
    return count if count.zero?

    expired.destroy_all
    Rails.logger.info("ProspectPurgeJob: #{count} prospect(s) supprimé(s) après #{Prospect::RETENTION.inspect}")
    count
  end

  private

  # Les signaux de la veille portent des noms d'entreprises et, pour les avis BODACC, de
  # dirigeants : la politique de confidentialité leur promet le même délai qu'aux fiches, à
  # compter du repérage. La fiche issue d'un signal survit (clé étrangère mise à nul).
  def purge_signals
    count = VeilleSignal.where(created_at: ...Prospect::RETENTION.ago).delete_all
    Rails.logger.info("ProspectPurgeJob: #{count} signal(aux) de veille supprimé(s)") if count.positive?
  end
end
