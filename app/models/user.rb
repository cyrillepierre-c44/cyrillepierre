class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  enum :role, { editor: 0, admin: 1 }

  has_many :generations, dependent: :destroy
  # Les prospects survivent à la suppression d'un compte : ce sont des pistes commerciales,
  # pas des contenus appartenant à un éditeur.
  has_many :prospects, dependent: :nullify

  encrypts :linkedin_access_token

  # En dessous de ce seuil, l'échéance passe en orange dans le Studio : il n'existe pas de
  # refresh token à ce niveau d'accès LinkedIn, la reconnexion est manuelle et doit être
  # anticipée — sinon la première publication ratée est le seul avertissement.
  LINKEDIN_EXPIRY_WARNING_DAYS = 14

  # Dernière ligne droite (aujourd'hui ou demain) : l'échéance passe en rouge, il faut agir
  # dans la journée.
  LINKEDIN_EXPIRY_CRITICAL_DAYS = 1

  def linkedin_connected?
    linkedin_access_token.present? && linkedin_token_expires_at.present? && linkedin_token_expires_at.future?
  end

  # Nombre de jours entiers avant l'expiration du token (0 le dernier jour).
  def linkedin_days_remaining
    return nil if linkedin_token_expires_at.blank?

    (linkedin_token_expires_at.to_date - Date.current).to_i
  end

  def linkedin_expiry_soon?
    days = linkedin_days_remaining
    days.present? && days <= LINKEDIN_EXPIRY_WARNING_DAYS
  end

  def linkedin_expiry_critical?
    days = linkedin_days_remaining
    days.present? && days <= LINKEDIN_EXPIRY_CRITICAL_DAYS
  end
end
