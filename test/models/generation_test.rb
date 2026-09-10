require "test_helper"

class GenerationTest < ActiveSupport::TestCase
  def build_generation(attrs = {})
    user = User.create!(email: "owner-#{SecureRandom.hex(4)}@example.com", password: "password123")
    Generation.new({ user: user, kind: :linkedin_post }.merge(attrs))
  end

  test "defaults to draft status" do
    generation = build_generation
    assert generation.draft?
  end

  test "is valid without any source" do
    assert build_generation.valid?
  end

  test "only site_actu is publishable" do
    assert build_generation(kind: :site_actu).publishable?
    assert build_generation(kind: :article).publishable?
    assert_not build_generation(kind: :linkedin_post).publishable?
    assert_not build_generation(kind: :cover_letter).publishable?
    assert_not build_generation(kind: :commercial_proposal).publishable?
  end

  test "cover_letter and commercial_proposal use structured output" do
    assert build_generation(kind: :cover_letter).structured_output?
    assert build_generation(kind: :commercial_proposal).structured_output?
    assert_not build_generation(kind: :linkedin_post).structured_output?
    assert_not build_generation(kind: :site_actu).structured_output?
  end

  test "sections splits structured output on markers" do
    generation = build_generation(
      kind: :cover_letter,
      output: <<~TEXT
        ###VERSION_FINALE###
        Texte final.
        ###A_PERSONNALISER###
        - point 1
        ###A_VERIFIER###
        Aucun élément à vérifier.
        ###VERSION_COURTE###
        Version courte.
      TEXT
    )

    sections = generation.sections
    assert_equal "Texte final.", sections[:final]
    assert_equal "- point 1", sections[:personalize]
    assert_equal "Aucun élément à vérifier.", sections[:verify]
    assert_equal "Version courte.", sections[:short]
  end

  test "sections falls back to raw output when markers are missing" do
    generation = build_generation(kind: :cover_letter, output: "Texte sans marqueurs")
    assert_equal({ final: "Texte sans marqueurs" }, generation.sections)
  end

  test "rejects an oversized file" do
    generation = build_generation
    generation.source_file.attach(
      io: StringIO.new("x" * (Generation::MAX_FILE_SIZE + 1)),
      filename: "big.txt",
      content_type: "text/plain"
    )
    assert_not generation.valid?
    assert_includes generation.errors[:source_file].join, "10 Mo"
  end

  test "rejects a disallowed file type" do
    generation = build_generation
    generation.source_file.attach(
      io: StringIO.new("<html></html>"),
      filename: "page.html",
      content_type: "text/html"
    )
    assert_not generation.valid?
  end

  test "accepts a plain text file" do
    generation = build_generation
    generation.source_file.attach(
      io: StringIO.new("hello"),
      filename: "notes.txt",
      content_type: "text/plain"
    )
    assert generation.valid?
  end

  test "accepts an attached visual" do
    generation = build_generation
    generation.visual.attach(
      io: StringIO.new("fake png bytes"),
      filename: "visual.png",
      content_type: "image/png"
    )
    assert generation.visual.attached?
  end

  test "auto-assigns a realisation for a sourceless linkedin post" do
    generation = build_generation
    generation.save!
    assert_includes RealisationCatalog::ITEMS.map { |r| r[:id] }, generation.realisation_id
  end

  test "does not auto-assign a realisation when a source is provided" do
    generation = build_generation(input_text: "Un brief précis sur un sujet donné")
    generation.save!
    assert_nil generation.realisation_id
  end

  test "does not override a manually chosen realisation" do
    generation = build_generation(realisation_id: "N°05")
    generation.save!
    assert_equal "N°05", generation.realisation_id
  end

  test "does not auto-assign a realisation for other kinds" do
    generation = build_generation(kind: :site_actu)
    generation.save!
    assert_nil generation.realisation_id
  end

  # Sans URN stocké, aucun moyen de reconstruire le permalien : mieux vaut ne rien afficher
  # qu'un lien cassé (l'API ne donne pas de droit de relecture des posts).
  test "linkedin_post_url is nil until the post urn is known" do
    assert_nil build_generation.linkedin_post_url
    assert_nil build_generation(linkedin_post_urn: "").linkedin_post_url
  end

  test "linkedin_post_url builds the public permalink from the urn" do
    generation = build_generation(linkedin_post_urn: "urn:li:share:123")

    assert_equal "https://www.linkedin.com/feed/update/urn:li:share:123/", generation.linkedin_post_url
  end

  test "unstructured kinds expose their whole output as the final section" do
    generation = build_generation(kind: :linkedin_post, output: "Un post d'une seule pièce.")

    assert_equal({ final: "Un post d'une seule pièce." }, generation.sections)
  end

  # Un marqueur suivi d'une section vide ne doit pas créer d'entrée : la vue afficherait un
  # bloc au titre sans contenu.
  test "sections skips a marker whose content is empty" do
    output = [
      Generation::SECTION_MARKERS[:final], "La lettre finale.",
      Generation::SECTION_MARKERS[:personalize], "",
      Generation::SECTION_MARKERS[:verify], "Vérifier la date."
    ].join("\n")
    generation = build_generation(kind: :cover_letter, output: output)

    sections = generation.sections

    assert_equal "La lettre finale.", sections[:final]
    assert_equal "Vérifier la date.", sections[:verify]
    assert_not sections.key?(:personalize)
  end
  test "published_on_site gathers the articles and the short news, newest first" do
    user = User.create!(email: "article-scope@example.com", password: "password123")
    actu = Generation.create!(user: user, kind: :site_actu, status: :published,
                              published_at: 2.days.ago, output: "Brève")
    article = Generation.create!(user: user, kind: :article, status: :published,
                                 published_at: 1.day.ago, output: "## Titre\n\nUn article.")
    Generation.create!(user: user, kind: :article, status: :generated, output: "Brouillon")
    Generation.create!(user: user, kind: :linkedin_post, status: :published,
                       published_at: Time.current, output: "Post")

    assert_equal [ article.id, actu.id ], Generation.published_on_site.pluck(:id)
  end

  test "display_title names the kind when the title is missing" do
    assert_equal "Article sans titre", build_generation(kind: :article).display_title
    assert_equal "Actualité", build_generation(kind: :site_actu).display_title
    assert_equal "Un titre", build_generation(kind: :article, title: "Un titre").display_title
  end

  test "excerpt drops the markdown so a list preview stays readable" do
    generation = build_generation(kind: :article, output: "## Un titre\n\nUn texte **en gras**.")

    assert_equal "Un titre Un texte en gras.", generation.excerpt
  end

  test "excerpt honours the requested length" do
    generation = build_generation(kind: :article, output: "a" * 300)

    assert_equal 155, generation.excerpt(length: 155).length
  end
end
