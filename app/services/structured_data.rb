# Le balisage schema.org du site. Sorti d'ApplicationHelper le 12/09/2026 : trois gros littéraux
# de données n'ont rien à faire dans un module de vues, et leur poids faisait dépasser la limite
# de longueur de module à la première ligne ajoutée.
module StructuredData
  # L'apex répond 301 vers www : toute adresse déclarée ici doit désigner www.
  HOST = "https://www.cyrillepierre.com".freeze

  DESCRIPTION = "Cyrille PIERRE — Manager de transition et consultant en excellence " \
                "opérationnelle. Ingénieur Arts & Métiers, 20 ans d'industrie. Lyon.".freeze

  def self.person
    {
      "@type" => "Person",
      "@id" => "#{HOST}/#person",
      "name" => "Cyrille PIERRE",
      "jobTitle" => "Manager de transition et consultant en excellence opérationnelle",
      # Un homonyme très référencé existe : l'ambassadeur de France auprès de l'OCDE. Cette
      # propriété de schema.org est faite pour distinguer deux entités qui portent le même nom.
      # On décrit CE Cyrille PIERRE de façon spécifique, sans jamais nommer l'autre.
      "disambiguatingDescription" => "Consultant indépendant et manager de transition en " \
                                     "industrie, basé à Lyon 4e. Ingénieur Arts et Métiers, " \
                                     "20 ans en direction de production et d'opérations " \
                                     "industrielles (agroalimentaire, pharmaceutique, " \
                                     "microélectronique, métallurgie).",
      "description" => DESCRIPTION,
      "url" => HOST,
      "image" => "#{HOST}/images/cyrille.jpg",
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

  def self.professional_service
    {
      "@type" => "ProfessionalService",
      "@id" => "#{HOST}/#service",
      "name" => "Cyrille PIERRE — Management de transition et excellence opérationnelle",
      "legalName" => "Centaur Bike",
      # C'est ce que Google lit pour afficher une vignette de marque à côté du nom.
      "logo" => "#{HOST}/images/logo-cp.png",
      "image" => "#{HOST}/images/logo-cp.png",
      "url" => HOST,
      "founder" => { "@id" => "#{HOST}/#person" },
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

  def self.article(actu)
    {
      "@context" => "https://schema.org",
      "@type" => "BlogPosting",
      "headline" => actu.display_title,
      "wordCount" => ArticleFormatter.plain_text(actu.output).split.size,
      "datePublished" => actu.published_at&.iso8601,
      "dateModified" => actu.updated_at.iso8601,
      "author" => { "@type" => "Person", "name" => "Cyrille PIERRE", "url" => HOST },
      "publisher" => { "@id" => "#{HOST}/#service" },
      "mainEntityOfPage" => "#{HOST}#{Rails.application.routes.url_helpers.actu_path(actu)}",
      "inLanguage" => "fr-FR"
    }.compact
  end

  # Couleur du badge selon l'urgence de la reconnexion : rouge le dernier jour, orange dans
  # les deux semaines qui précèdent, neutre au-delà.
end
