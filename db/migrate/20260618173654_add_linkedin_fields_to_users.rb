class AddLinkedinFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :linkedin_access_token, :text
    add_column :users, :linkedin_token_expires_at, :datetime
    add_column :users, :linkedin_member_urn, :string
  end
end
