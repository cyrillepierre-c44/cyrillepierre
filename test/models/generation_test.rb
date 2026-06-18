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
end
