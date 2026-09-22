# Les signaux de la routine de veille du lundi arrivaient seulement par mail : rien à cocher,
# tout à ressaisir. Ils sont désormais déposés ici, à valider dans le Studio, et chaque signal
# retenu devient une fiche prospect déjà remplie.
class CreateVeilleSignals < ActiveRecord::Migration[8.1]
  def change
    create_table :veille_signals do |t|
      t.date :run_week, null: false
      t.integer :rank
      t.boolean :shortlisted, null: false, default: true
      t.string :company, null: false
      t.string :location
      t.string :sector
      t.string :signal_type, null: false
      t.text :signal, null: false
      t.string :source_name
      t.string :source_url, null: false
      t.date :published_on
      t.text :why_now
      t.string :comparable
      t.text :pitch
      t.integer :status, null: false, default: 0
      t.references :prospect, foreign_key: { on_delete: :nullify }
      t.timestamps
    end
    add_index :veille_signals, %i[run_week source_url], unique: true
    add_index :veille_signals, :status
  end
end
