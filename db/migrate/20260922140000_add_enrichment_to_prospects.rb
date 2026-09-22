# Les renseignements publics d'une fiche (annuaire officiel, BODACC, presse) se cherchaient à la
# main à chaque prospect : ils sont désormais rassemblés par ProspectEnricher, datés, et relus par
# les générations qui partent de la fiche.
class AddEnrichmentToProspects < ActiveRecord::Migration[8.1]
  def change
    add_column :prospects, :siren, :string
    add_column :prospects, :enrichment, :text
    add_column :prospects, :enrichment_requested_at, :datetime
    add_column :prospects, :enriched_at, :datetime
  end
end
