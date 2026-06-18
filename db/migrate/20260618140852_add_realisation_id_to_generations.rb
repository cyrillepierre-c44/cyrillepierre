class AddRealisationIdToGenerations < ActiveRecord::Migration[8.1]
  def change
    add_column :generations, :realisation_id, :string
  end
end
