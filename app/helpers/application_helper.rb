module ApplicationHelper
  # L'apex redirige vers www : les URL canoniques et le sitemap doivent donc toutes désigner
  # www, sinon on déclare des adresses qui répondent 301. Constante plutôt que `request.host`
  # pour que l'URL de production reste la référence même vue depuis Heroku ou le local.
  CANONICAL_HOST = "https://www.cyrillepierre.com".freeze

  def canonical_url(path = nil)
    "#{CANONICAL_HOST}#{path || request.path}"
  end

  # Une description par page. Sans elle, Google affichait le même extrait sous les cinq pages
  # de services, qui se ressemblaient donc autant dans les résultats que sur le site.
  DEFAULT_DESCRIPTION = "Cyrille PIERRE — Manager de transition et consultant en excellence " \
                        "opérationnelle. Ingénieur Arts & Métiers, 20 ans d'industrie. Lyon.".freeze

  def page_description
    content_for(:description).presence || DEFAULT_DESCRIPTION
  end

  # Les assistants ne recommandent pas une page, ils recommandent une entité qu'ils ont su
  # identifier. Ce bloc est la seule chose du site qui dise à une machine QUI est Cyrille
  # PIERRE, ce qu'il fait et où — le reste n'est que du texte à interpréter.
  def structured_data_tag(data)
    tag.script(raw(data.to_json), type: "application/ld+json", nonce: content_security_policy_nonce)
  end

  def person_schema
    {
      "@type" => "Person",
      "@id" => "#{CANONICAL_HOST}/#person",
      "name" => "Cyrille PIERRE",
      "jobTitle" => "Manager de transition et consultant en excellence opérationnelle",
      "description" => DEFAULT_DESCRIPTION,
      "url" => CANONICAL_HOST,
      "image" => "#{CANONICAL_HOST}/images/cyrille.jpg",
      "email" => "cyrille.pierre@gmail.com",
      "telephone" => "+33618022452",
      "sameAs" => ["https://www.linkedin.com/in/cyrille-pierre"],
      "alumniOf" => { "@type" => "CollegeOrUniversity", "name" => "Arts et Métiers ParisTech" },
      "address" => {
        "@type" => "PostalAddress",
        "addressLocality" => "Lyon",
        "addressRegion" => "Auvergne-Rhône-Alpes",
        "addressCountry" => "FR"
      },
      "workLocation" => { "@type" => "Place", "name" => "Lyon, Auvergne-Rhône-Alpes, France" },
      "knowsAbout" => [
        "Management de transition", "Excellence opérationnelle", "Lean manufacturing",
        "TRS (taux de rendement synthétique)", "Conduite du changement", "Industrie agroalimentaire",
        "Industrie pharmaceutique", "Digitalisation des processus industriels",
        "Ruby on Rails", "Intelligence artificielle appliquée à l'industrie"
      ]
    }
  end

  def professional_service_schema
    {
      "@type" => "ProfessionalService",
      "@id" => "#{CANONICAL_HOST}/#service",
      "name" => "Cyrille PIERRE — Management de transition et excellence opérationnelle",
      "legalName" => "Centaur Bike",
      "url" => CANONICAL_HOST,
      "founder" => { "@id" => "#{CANONICAL_HOST}/#person" },
      "email" => "cyrille.pierre@gmail.com",
      "telephone" => "+33618022452",
      "vatID" => "FR52892208018",
      "address" => {
        "@type" => "PostalAddress",
        "streetAddress" => "13 rue Villeneuve",
        "postalCode" => "69004",
        "addressLocality" => "Lyon",
        "addressRegion" => "Auvergne-Rhône-Alpes",
        "addressCountry" => "FR"
      },
      # Un simple « France » ne disait pas où se trouve Cyrille : on nomme la ville et la
      # région avant le pays, puisque c'est ce que cherche une requête « métier + ville ».
      "areaServed" => [
        { "@type" => "City", "name" => "Lyon" },
        { "@type" => "AdministrativeArea", "name" => "Auvergne-Rhône-Alpes" },
        { "@type" => "Country", "name" => "France" }
      ],
      "knowsLanguage" => ["fr", "en"]
    }
  end

  def actu_schema(actu)
    {
      "@context" => "https://schema.org",
      "@type" => "BlogPosting",
      "headline" => actu.display_title,
      "wordCount" => ArticleFormatter.plain_text(actu.output).split.size,
      "datePublished" => actu.published_at&.iso8601,
      "dateModified" => actu.updated_at.iso8601,
      "author" => { "@type" => "Person", "name" => "Cyrille PIERRE", "url" => CANONICAL_HOST },
      "publisher" => { "@id" => "#{CANONICAL_HOST}/#service" },
      "mainEntityOfPage" => canonical_url(actu_path(actu)),
      "inLanguage" => "fr-FR"
    }.compact
  end

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
