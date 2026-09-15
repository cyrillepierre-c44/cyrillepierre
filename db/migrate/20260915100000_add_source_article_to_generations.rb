class AddSourceArticleToGenerations < ActiveRecord::Migration[8.1]
  def change
    add_reference :generations, :source_article, null: true, foreign_key: { to_table: :generations }
  end
end
