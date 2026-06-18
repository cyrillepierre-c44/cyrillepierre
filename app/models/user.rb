class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  enum :role, { editor: 0, admin: 1 }

  has_many :generations, dependent: :destroy

  encrypts :linkedin_access_token

  def linkedin_connected?
    linkedin_access_token.present? && linkedin_token_expires_at.present? && linkedin_token_expires_at.future?
  end
end
