# Applique la durée de conservation annoncée dans /politique-de-confidentialite. Sans ce job,
# la page promettrait une suppression qui n'arriverait jamais.
#
# Planifié dans config/recurring.yml (production uniquement). Solid Queue tourne dans le
# process Puma via SOLID_QUEUE_IN_PUMA : sans cette variable sur Heroku, rien ne s'exécute.
class ProspectPurgeJob < ApplicationJob
  queue_as :default

  def perform
    expired = Prospect.expired
    count = expired.count
    return count if count.zero?

    expired.destroy_all
    Rails.logger.info("ProspectPurgeJob: #{count} prospect(s) supprimé(s) après #{Prospect::RETENTION.inspect}")
    count
  end
end
