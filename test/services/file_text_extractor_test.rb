require "test_helper"

class FileTextExtractorTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "extract-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @generation = Generation.create!(user: user, kind: :cover_letter)
  end

  def attach(io:, filename:, content_type:)
    @generation.source_file.attach(io: io, filename: filename, content_type: content_type)
    @generation.source_file
  end

  test "returns nil when nothing is attached" do
    assert_nil FileTextExtractor.call(@generation.source_file)
  end

  test "returns the raw content of a text file" do
    attachment = attach(io: StringIO.new("Contexte de la mission."), filename: "brief.txt",
                        content_type: "text/plain")

    assert_equal "Contexte de la mission.", FileTextExtractor.call(attachment)
  end

  test "extracts the text of a PDF instead of its binary content" do
    attachment = attach(io: File.open(file_fixture("sample.pdf")), filename: "sample.pdf",
                        content_type: "application/pdf")

    text = FileTextExtractor.call(attachment)

    assert_includes text, "Bonjour depuis le PDF de test"
    assert_not_includes text, "%PDF"
  end

  # Le texte part dans un prompt : sans plafond, un gros fichier ferait exploser la requête.
  test "truncates beyond MAX_TEXT_LENGTH, without an ellipsis" do
    oversized = "a" * (FileTextExtractor::MAX_TEXT_LENGTH + 500)
    attachment = attach(io: StringIO.new(oversized), filename: "long.txt", content_type: "text/plain")

    text = FileTextExtractor.call(attachment)

    assert_equal FileTextExtractor::MAX_TEXT_LENGTH, text.length
    assert_not_includes text, "..."
  end
end
