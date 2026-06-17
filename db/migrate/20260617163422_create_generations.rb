class CreateGenerations < ActiveRecord::Migration[8.1]
  def change
    create_table :generations do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :kind, null: false, default: 0
      t.string :title
      t.text :input_text
      t.string :input_url
      t.text :extra_instructions
      t.text :output
      t.integer :status, null: false, default: 0
      t.datetime :published_at

      t.timestamps
    end
  end
end
