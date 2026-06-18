class AddLlmModelToGenerations < ActiveRecord::Migration[8.1]
  def change
    add_column :generations, :llm_model, :string, null: false, default: "gpt-4o"
  end
end
