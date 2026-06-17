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
    assert_not build_generation(kind: :job_application).publishable?
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
