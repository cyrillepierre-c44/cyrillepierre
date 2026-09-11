require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "the public pages render" do
    [ root_path, operations_path, leadership_path, tech_path, realisations_path,
      legal_path, privacy_path ].each do |path|
      get path

      assert_response :success, "#{path} n'a pas répondu correctement"
    end
  end

  test "mentions legales name the publisher and the host" do
    get legal_path

    assert_response :success
    assert_select "h1", text: /Mentions/
    assert_includes @response.body, "Heroku"
    assert_includes @response.body, "Directeur de la publication"
  end

  test "mentions legales carry the identifiers required of a company" do
    get legal_path

    assert_includes @response.body, "Centaur Bike"
    assert_includes @response.body, "892 208 018 00010"
    assert_includes @response.body, "FR 52 892 208 018"
    assert_includes @response.body, "RCS"
    assert_includes @response.body, "capital"
    assert_select ".legal-todo", 0, "une valeur légale est encore en attente"
  end

  test "the privacy policy states the retention period and the LLM transfer" do
    get privacy_path

    assert_response :success
    assert_includes @response.body, "trois ans"
    assert_includes @response.body, "modèle de langage"
    assert_select ".legal-warning", 1
    assert_select ".legal-table tbody tr", minimum: 5
  end

  test "both legal pages link to each other" do
    get legal_path
    assert_select "a[href=?]", privacy_path

    get privacy_path
    assert_select "a[href=?]", legal_path
  end

  test "the footer links to both legal pages from any public page" do
    get root_path

    assert_select ".footer-copy a[href=?]", legal_path
    assert_select ".footer-copy a[href=?]", privacy_path
  end

  test "the contact form points to the privacy policy" do
    get contact_path

    assert_select ".cf-rgpd-notice a[href=?]", privacy_path
  end

  test "the CV page renders without the site layout" do
    get cv_path

    assert_response :success
    assert_select "nav.navbar-cp", 0
  end

  # La page CV n'utilise pas le gabarit du site : ses balises doivent être posées à la main,
  # et rien d'autre ne les protège d'une suppression accidentelle.
  test "the CV page carries its own indexing and sharing tags" do
    get cv_path

    assert_select "h1", 1
    assert_select "link[rel=canonical][href=?]", "https://www.cyrillepierre.com/cv"
    assert_select "meta[name=description]"
    assert_select "meta[property='og:image']"
    assert_select "script[type='application/ld+json']", 1
  end

  test "the CV states the identity and the reach of the master CV" do
    get cv_path

    assert_select "h1", text: /PIERRE/
    assert_includes @response.body, "Directeur Industriel"
    assert_includes @response.body, "TOEIC 835"
    assert_includes @response.body, "Sept. 2025 → Aujourd'hui"
    assert_includes @response.body, "HEC Paris"
  end
  # Avant, les quatre pages de fond n'offraient qu'un lien vers le contact : un visiteur pas
  # encore prêt à écrire n'avait nulle part où aller, et les moteurs voyaient des culs-de-sac.
  test "each deep page offers a way onward other than the contact form" do
    { operations_path => [ realisations_path, tech_path, actus_path ],
      leadership_path => [ realisations_path, operations_path, actus_path ],
      tech_path => [ realisations_path, operations_path, actus_path ],
      realisations_path => [ operations_path, leadership_path, tech_path ],
      root_path => [ realisations_path, actus_path, cv_path ] }.each do |page, targets|
      get page

      assert_select ".related-list li", 3, "#{page} devrait proposer trois pages liées"
      targets.each do |target|
        assert_select ".related-link[href=?]", target, { count: 1 }, "#{page} ne renvoie pas vers #{target}"
      end
    end
  end

  test "the related links describe where they lead" do
    get operations_path

    assert_select ".related-link-title", text: "Les réalisations chiffrées"
    assert_select ".related-link-desc", minimum: 3
    assert_select ".related-link", text: /ici/i, count: 0
  end
end
