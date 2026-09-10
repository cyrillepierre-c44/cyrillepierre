class CreateProspects < ActiveRecord::Migration[8.1]
  def change
    create_table :prospects do |t|
      t.references :user, foreign_key: true

      t.string :name
      t.string :email
      t.string :company
      t.string :phone
      t.string :sector
      t.string :company_size

      t.integer :source, default: 0, null: false
      t.integer :status, default: 0, null: false
      t.string  :themes, array: true, default: []

      t.text :summary
      t.text :conversation
      t.text :visitor_precision
      t.text :notes

      t.datetime :last_contact_at
      t.string   :next_action
      t.date     :next_action_on

      t.timestamps
    end

    add_index :prospects, :status
    add_index :prospects, :next_action_on
  end
end
