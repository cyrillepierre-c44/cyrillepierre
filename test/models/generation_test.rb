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
    assert_not build_generation(kind: :executive_brief).publishable?
  end

  test "cover_letter and commercial_proposal use structured output" do
    assert build_generation(kind: :cover_letter).structured_output?
    assert build_generation(kind: :commercial_proposal).structured_output?
    assert build_generation(kind: :executive_brief).structured_output?
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
  # --- post LinkedIn tiré d'un article ---------------------------------------

  def published_article(user)
    Generation.create!(user: user, kind: :article, status: :published, published_at: Time.current,
                       title: "Passer en 3x8", output: "## Section\n\nDu texte.")
  end

  test "a post can promote a published article" do
    generation = build_generation(kind: :linkedin_post)
    generation.source_article = published_article(generation.user)

    assert generation.valid?
  end

  test "a post refuses to promote something that is not a published article" do
    generation = build_generation(kind: :linkedin_post)
    brouillon = Generation.create!(user: generation.user, kind: :article, output: "Brouillon")
    generation.source_article = brouillon

    assert_not generation.valid?
    assert_includes generation.errors[:source_article], "doit être un article publié"
  end

  test "a post refuses to promote a short news rather than an article" do
    generation = build_generation(kind: :linkedin_post)
    breve = Generation.create!(user: generation.user, kind: :site_actu, status: :published,
                               published_at: Time.current, output: "Brève")
    generation.source_article = breve

    assert_not generation.valid?
  end

  # Un post tiré d'un article a déjà son sujet : la rotation lui ferait parler d'autre chose.
  test "promoting an article suspends the automatic realisation rotation" do
    user = User.create!(email: "rotation@example.com", password: "password123")
    article = published_article(user)

    post = Generation.create!(user: user, kind: :linkedin_post, source_article: article)

    assert_nil post.realisation_id
  end

  test "an ordinary post without source still gets its realisation" do
    user = User.create!(email: "rotation-2@example.com", password: "password123")

    post = Generation.create!(user: user, kind: :linkedin_post)

    assert post.realisation_id.present?
  end

  test "public_url points at the page a reader can actually open" do
    generation = build_generation(kind: :article)
    generation.save!

    assert_equal "https://www.cyrillepierre.com/actus/#{generation.id}", generation.public_url
  end


  test "locked_realisation resolves the catalogue entry, or nothing when none is set" do
    user = User.create!(email: "lock-#{SecureRandom.hex(4)}@example.com", password: "password123")
    id = RealisationCatalog::ITEMS.first[:id]
    locked = Generation.new(user: user, kind: :linkedin_post, realisation_id: id)
    free = Generation.new(user: user, kind: :cover_letter, realisation_id: nil)

    assert_equal id, locked.locked_realisation[:id]
    assert_nil free.locked_realisation
  end


  # La note de diagnostic partage le format en quatre sections, mais sa quatrième section est la
  # lettre d'accompagnement, pas un résumé : le libellé doit le dire dans le Studio.
  test "the executive brief names its sections and its kind in French" do
    brief = build_generation(kind: :executive_brief)

    assert_equal "Lettre d'accompagnement", brief.section_labels[:short]
    assert_equal "Version courte", build_generation(kind: :cover_letter).section_labels[:short]
    assert_equal "Note de diagnostic dirigeant", brief.kind_name
    assert_equal "Note de diagnostic", brief.display_title
  end

  # --- message de premier contact ------------------------------------------------------------

  def outreach(prospect: nil, output: nil)
    output ||= "###VERSION_FINALE###\nBonjour, j'ai vu votre annonce…\n\n###A_PERSONNALISER###\n- x\n\n" \
               "###VERSION_COURTE###\nObjet : Votre annonce sur Indeed\nBonjour,\n\nCorps.\n\nCyrille PIERRE"
    Generation.create!(user: users_owner, prospect: prospect, kind: :outreach_message, status: :generated, output: output)
  end

  def users_owner
    @users_owner ||= User.create!(email: "outreach-#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  test "the outreach message is structured, audited, and reads its email subject and body from the short section" do
    message = outreach

    assert message.structured_output?
    assert message.audited?
    assert_equal "Message LinkedIn", message.section_labels[:final]
    assert_equal "Corrections automatiques", message.section_labels[:verify]
    assert_equal "Votre annonce sur Indeed", message.email_subject
    assert_equal "Bonjour,\n\nCorps.\n\nCyrille PIERRE", message.email_body
    assert_equal "Premier contact", message.default_title
  end

  test "an email variant without an explicit subject falls back on the prospect company" do
    prospect = Prospect.create!(user: users_owner, name: "X", company: "Aldes — Vénissieux", email: "x@example.com")
    message = outreach(prospect: prospect, output: "###VERSION_FINALE###\nMsg\n\n###VERSION_COURTE###\nBonjour,\n\nCorps.")

    assert_equal "Prise de contact — Aldes — Vénissieux", message.email_subject
    assert_equal "Bonjour,\n\nCorps.", message.email_body
  end

  test "an outreach is sendable by email only with a generated text and a prospect that has an email" do
    assert_not outreach.email_sendable?
    prospect = Prospect.create!(user: users_owner, name: "X", company: "Y")
    assert_not outreach(prospect: prospect).email_sendable?
    prospect.update!(email: "y@example.com")
    assert outreach(prospect: prospect).email_sendable?
  end

  test "marking as sent stamps the generation and turns the prospect sheet into the contact journal" do
    prospect = Prospect.create!(user: users_owner, name: "X", company: "Y", email: "y@example.com",
                                status: :a_contacter, notes: "SIGNAL : annonce.", next_action_on: Date.current)
    message = outreach(prospect: prospect)

    travel_to Time.zone.local(2026, 9, 23, 10, 0) do
      message.mark_sent!("email")

      assert message.reload.sent?
      assert_equal "email", message.sent_via
      prospect.reload
      assert_includes prospect.notes, "SIGNAL : annonce.\n23/09/2026 : premier message envoyé par email (génération ##{message.id})."
      assert_equal Date.new(2026, 9, 30), prospect.next_action_on
      assert_equal "Relancer si pas de réponse au premier message (email)", prospect.next_action
      assert_equal Time.zone.local(2026, 9, 23, 10, 0), prospect.last_contact_at
      assert prospect.a_contacter?
    end
  end

  test "deleting the prospect keeps the message" do
    prospect = Prospect.create!(user: users_owner, name: "X", company: "Y")
    message = outreach(prospect: prospect)
    prospect.destroy!

    assert_nil message.reload.prospect
  end
end
