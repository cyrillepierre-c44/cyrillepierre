class AddLinkedinPublishedAtToGenerations < ActiveRecord::Migration[8.1]
  def change
    add_column :generations, :linkedin_published_at, :datetime
  end
end
