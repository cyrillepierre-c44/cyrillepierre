class AddImageModelToGenerations < ActiveRecord::Migration[8.1]
  def change
    add_column :generations, :image_model, :string, default: "gemini-2.5-flash-image", null: false
  end
end
