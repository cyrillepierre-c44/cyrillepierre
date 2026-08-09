module ApplicationHelper
  # Couleur du badge selon l'urgence de la reconnexion : rouge le dernier jour, orange dans
  # les deux semaines qui précèdent, neutre au-delà.
  def linkedin_expiry_badge_modifier(user)
    return "studio-badge--danger" if user.linkedin_expiry_critical?
    return "studio-badge--warning" if user.linkedin_expiry_soon?

    nil
  end

  # Échéance du token LinkedIn, affichée sous le badge « LinkedIn connecté » du Studio.
  def linkedin_expiry_label(user)
    days = user.linkedin_days_remaining
    return nil if days.blank?

    case days
    when ..0 then "expire aujourd'hui"
    when 1   then "expire demain"
    else          "expire dans #{days} jours"
    end
  end
end
