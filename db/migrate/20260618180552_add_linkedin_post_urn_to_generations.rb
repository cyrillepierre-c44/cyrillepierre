class AddLinkedinPostUrnToGenerations < ActiveRecord::Migration[8.1]
  def change
    add_column :generations, :linkedin_post_urn, :string
  end
end
