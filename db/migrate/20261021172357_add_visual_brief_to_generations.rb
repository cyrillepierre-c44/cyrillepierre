class AddVisualBriefToGenerations < ActiveRecord::Migration[8.1]
  def change
    add_column :generations, :visual_brief, :text
  end
end
