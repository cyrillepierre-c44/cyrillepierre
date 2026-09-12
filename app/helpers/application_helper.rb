module ApplicationHelper
  # L'apex redirige vers www : les URL canoniques et le sitemap doivent donc toutes désigner
  # www, sinon on déclare des adresses qui répondent 301. Constante plutôt que `request.host`
  # pour que l'URL de production reste la référence même vue depuis Heroku ou le local.
  # Les valeurs vivent dans StructuredData ; le module de vues les ré-expose pour que les
  # gabarits et les tests continuent de les nommer ici.
  CANONICAL_HOST = StructuredData::HOST

  def canonical_url(path = nil)
    "#{CANONICAL_HOST}#{path || request.path}"
  end

  # Une description par page. Sans elle, Google affichait le même extrait sous les cinq pages
  # de services, qui se ressemblaient donc autant dans les résultats que sur le site.
  DEFAULT_DESCRIPTION = StructuredData::DESCRIPTION

  def page_description
    content_for(:description).presence || DEFAULT_DESCRIPTION
  end

  # Les assistants ne recommandent pas une page, ils recommandent une entité qu'ils ont su
  # identifier. Ce bloc est la seule chose du site qui dise à une machine QUI est Cyrille
  # PIERRE, ce qu'il fait et où — le reste n'est que du texte à interpréter.
  def person_schema = StructuredData.person
  def professional_service_schema = StructuredData.professional_service
  def actu_schema(actu) = StructuredData.article(actu)

  def structured_data_tag(data)
    tag.script(raw(data.to_json), type: "application/ld+json", nonce: content_security_policy_nonce)
  end

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
