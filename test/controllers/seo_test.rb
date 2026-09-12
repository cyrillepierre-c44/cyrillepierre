require "test_helper"

# Ce que les robots et les assistants lisent réellement du site. Ces balises n'ont aucun effet
# visible : sans test, une régression passerait inaperçue jusqu'au prochain audit.
class SeoTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "seo@example.com", password: "password123")
    @actu = Generation.create!(user: @user, kind: :site_actu, status: :published,
                               published_at: Time.current, title: "Retour de terrain",
                               output: "Un atelier gagne rarement en performance par l'outil seul.")
  end

  # --- sitemap ---------------------------------------------------------------

  test "the sitemap lists the public pages with their canonical host" do
    get "/sitemap.xml"

    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_includes response.body, "<loc>https://www.cyrillepierre.com/</loc>"
    assert_includes response.body, "<loc>https://www.cyrillepierre.com/realisations</loc>"
    assert_includes response.body, "<loc>https://www.cyrillepierre.com/mentions-legales</loc>"
  end

  test "the sitemap follows the published actus" do
    draft = Generation.create!(user: @user, kind: :site_actu, status: :generated, output: "Brouillon")

    get "/sitemap.xml"

    assert_includes response.body, "https://www.cyrillepierre.com/actus/#{@actu.id}"
    assert_not_includes response.body, "https://www.cyrillepierre.com/actus/#{draft.id}"
  end

  test "the sitemap still dates itself before the first actu is published" do
    @actu.destroy

    get "/sitemap.xml"

    assert_response :success
    assert_includes response.body, "<loc>https://www.cyrillepierre.com/</loc>"
    assert_match %r{<lastmod>\d{4}-\d{2}-\d{2}T}, response.body
  end

  test "the sitemap never leaks a private page" do
    get "/sitemap.xml"

    assert_not_includes response.body, "/studio"
    assert_not_includes response.body, "/users"
  end

  test "robots points to the sitemap and keeps the studio out" do
    robots = Rails.root.join("public/robots.txt").read

    assert_includes robots, "Sitemap: https://www.cyrillepierre.com/sitemap.xml"
    assert_includes robots, "Disallow: /studio/"
  end

  # --- métadonnées par page --------------------------------------------------

  test "each page carries its own description" do
    descriptions = [ root_path, operations_path, tech_path, realisations_path ].map do |path|
      get path
      css_select("meta[name='description']").first["content"]
    end

    assert_equal descriptions.uniq.length, descriptions.length, "deux pages partagent la même description"
    assert(descriptions.all? { |d| d.length.between?(80, 200) })
  end

  test "a page without its own description falls back on the site one" do
    get new_user_session_path

    assert_equal ApplicationHelper::DEFAULT_DESCRIPTION, css_select("meta[name='description']").first["content"]
  end

  test "the canonical URL points to the www host actually served" do
    get operations_path

    assert_equal "https://www.cyrillepierre.com/expertise-operationnelle",
                 css_select("link[rel='canonical']").first["href"]
  end

  # --- données structurées ---------------------------------------------------

  test "every page declares who Cyrille PIERRE is" do
    get root_path

    graph = JSON.parse(css_select("script[type='application/ld+json']").first.text)["@graph"]
    person = graph.find { |node| node["@type"] == "Person" }
    service = graph.find { |node| node["@type"] == "ProfessionalService" }

    assert_equal "Cyrille PIERRE", person["name"]
    assert_includes person["sameAs"], "https://www.linkedin.com/in/cyrille-pierre"
    assert_equal "Lyon", person["address"]["addressLocality"]
    assert_equal "Auvergne-Rhône-Alpes", person["address"]["addressRegion"]
    assert_equal "Centaur Bike", service["legalName"]
    assert_equal "https://www.cyrillepierre.com/images/logo-cp.png", service["logo"]
    assert_equal person["@id"], service["founder"]["@id"]
  end

  test "an actu is marked up as an article" do
    get actu_path(@actu)

    schemas = css_select("script[type='application/ld+json']").map { |tag| JSON.parse(tag.text) }
    article = schemas.find { |s| s["@type"] == "BlogPosting" }

    assert_equal "Retour de terrain", article["headline"]
    assert_equal "Cyrille PIERRE", article["author"]["name"]
    assert_equal "https://www.cyrillepierre.com/actus/#{@actu.id}", article["mainEntityOfPage"]
  end

  test "an actu without title nor publication date still produces valid markup" do
    bare = Generation.create!(user: @user, kind: :site_actu, status: :published, output: "Sans titre.")

    get actu_path(bare)

    schemas = css_select("script[type='application/ld+json']").map { |tag| JSON.parse(tag.text) }
    article = schemas.find { |s| s["@type"] == "BlogPosting" }

    assert_equal "Actualité", article["headline"]
    assert_not article.key?("datePublished")
  end

  # La CSP bloque tout inline sans nonce : sans lui, ce bloc disparaîtrait de la page.
  test "the structured data carries the CSP nonce" do
    get root_path

    assert css_select("script[type='application/ld+json']").first["nonce"].present?
  end
  # Une requête « métier + ville » cherche un professionnel situé quelque part. Le site disait
  # ce que fait Cyrille, jamais où il est : « Lyon » n'apparaissait qu'une fois par page, dans
  # le pied de page, et la région nulle part.
  test "the structured data names the city and the region served" do
    get root_path

    graph = JSON.parse(css_select("script[type='application/ld+json']").first.text)["@graph"]
    service = graph.find { |node| node["@type"] == "ProfessionalService" }
    served = service["areaServed"].map { |a| a["name"] }

    assert_equal [ "Lyon", "Auvergne-Rhône-Alpes", "France" ], served
    assert_equal "Auvergne-Rhône-Alpes", service["address"]["addressRegion"]
  end

  test "each service page states where Cyrille actually works" do
    [ operations_path, leadership_path, tech_path ].each do |path|
      get path

      assert_select ".zone-block", 1, "#{path} devrait annoncer sa zone d'intervention"
      assert_select ".zone-block strong", text: "Lyon"
      assert_select ".zone-block strong", text: "Auvergne-Rhône-Alpes"
    end
  end

  test "the service descriptions carry the geography too" do
    [ operations_path, leadership_path, tech_path ].each do |path|
      get path

      description = css_select("meta[name='description']").first["content"]
      assert_includes description, "Lyon", "la description de #{path} devrait situer Cyrille"
    end
  end
  # Le manifeste était resté celui du squelette Rails : un nom de projet, une description vide
  # de sens, deux fois la même icône déclarée en 512 alors qu'elle en faisait 64, et un écran
  # de démarrage ROUGE sur un site bleu nuit.
  test "the installed app carries the brand, not the Rails scaffold" do
    get "/manifest.json"

    manifest = JSON.parse(@response.body)
    assert_equal "Cyrille PIERRE", manifest["short_name"]
    assert_equal "#050a15", manifest["theme_color"]
    assert_equal "#050a15", manifest["background_color"]
    assert_includes manifest["description"], "Lyon"
  end

  # Servi depuis public/, le manifeste héritait d'un cache d'un an : un nom corrigé n'atteignait
  # jamais un téléphone qui avait déjà installé le site.
  test "the manifest can actually be refetched" do
    get "/manifest.json"

    assert_response :success
    max_age = @response.headers["Cache-Control"][/max-age=(\d+)/, 1].to_i
    assert max_age <= 1.day.to_i, "le manifeste est caché #{max_age} s, il ne se rafraîchira jamais"
  end

  test "every declared icon exists and really has the declared size" do
    get "/manifest.json"

    JSON.parse(@response.body)["icons"].each do |icon|
      path = Rails.root.join("public", icon["src"].delete_prefix("/"))
      assert path.exist?, "#{icon['src']} est déclarée mais absente"
      width = path.binread(24)[16, 4].unpack1("N")
      assert_equal icon["sizes"].split("x").first.to_i, width, "#{icon['src']} n'a pas la taille déclarée"
    end
  end

  test "one icon is maskable, cropped safely by Android" do
    get "/manifest.json"

    purposes = JSON.parse(@response.body)["icons"].map { |i| i["purpose"] }
    assert_includes purposes, "maskable"
    assert_includes purposes, "any"
  end
end
