# Un message de premier contact est écrit POUR une fiche prospect et part vers elle : la génération
# connaît désormais son prospect, et retient quand et par quel canal elle a été envoyée.
class AddProspectAndSendingToGenerations < ActiveRecord::Migration[8.1]
  def change
    add_reference :generations, :prospect, foreign_key: { on_delete: :nullify }
    add_column :generations, :sent_at, :datetime
    add_column :generations, :sent_via, :string
  end
end
