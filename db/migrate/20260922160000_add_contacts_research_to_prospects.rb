# Le décideur du site n'est dans aucun registre : il se cherche sur le web (Tavily), les noms
# trouvés sont vérifiés mot pour mot dans leurs sources, et la fiche garde le résultat daté.
class AddContactsResearchToProspects < ActiveRecord::Migration[8.1]
  def change
    add_column :prospects, :contacts_research, :text
    add_column :prospects, :contacts_requested_at, :datetime
    add_column :prospects, :contacts_researched_at, :datetime
  end
end
