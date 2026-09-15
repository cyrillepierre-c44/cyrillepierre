class AddGeneratingSinceToGenerations < ActiveRecord::Migration[8.1]
  def change
    add_column :generations, :generating_since, :datetime
  end
end
