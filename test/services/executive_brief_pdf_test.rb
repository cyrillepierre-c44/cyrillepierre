require "test_helper"
require "pdf/reader"

# Le PDF suit la grammaire restreinte d'ArticleFormatter, avec la même précaution : le texte du
# modèle est échappé avant toute interprétation. Les polices vendorées couvrent les caractères que
# les polices intégrées de Prawn ne connaissent pas (→, ×, ≈, €).
class ExecutiveBriefPdfTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "pdf-#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  def brief(final)
    output = "#{Generation::SECTION_MARKERS[:final]}\n#{final}\n#{Generation::SECTION_MARKERS[:short]}\nLettre."
    Generation.create!(user: @user, kind: :executive_brief, title: "Livron: turning capacity into result",
                       status: :generated, output: output)
  end

  def text_of(pdf_bytes)
    reader = PDF::Reader.new(StringIO.new(pdf_bytes))
    [ reader, reader.pages.map(&:text).join("\n") ]
  end

  test "renders headings, paragraphs, lists, bold and links on A4 pages with a footer" do
    final = "Intro with **bold** and a [link](https://www.cyrillepierre.com/actus/174).\n\n" \
            "## Ce que vos comptes disent\n\nUn paragraphe.\n\n### Sous-titre\n\n- premier\n- second\n\n1. un\n2. deux"
    reader, text = text_of(ExecutiveBriefPdf.call(brief(final)))

    assert reader.pages.first.attributes[:MediaBox].map(&:to_f).last.between?(841, 842), "page A4 attendue"
    assert_includes text, "Livron: turning capacity into result"
    assert_includes text, "Ce que vos comptes disent"
    assert_includes text, "Sous-titre"
    assert_includes text, "premier"
    assert_includes text, "deux"
    assert_includes text, "CONFIDENTIEL"
    assert_includes text, SiteIdentity::PHONE_DISPLAY
    assert_includes text, "1 / 1"
    assert_not_includes text, "**"
    assert_not_includes text, "](https"
  end

  # Un lien markdown devient une annotation cliquable dans le PDF : c'est ce qui permet de
  # renvoyer vers un article ou vers la fiche d'une réalisation sur le site.
  test "markdown links become clickable pdf annotations" do
    url = RealisationCatalog.public_url(RealisationCatalog::ITEMS.first)
    pdf = ExecutiveBriefPdf.call(brief("At [Yoplait](#{url}) the site gained **8 points**."))

    assert_includes pdf, url, "l'adresse doit figurer dans l'annotation de lien"
    assert_match(/\/URI/, pdf)
  end

  test "escapes markup coming from the model and keeps unusual characters" do
    final = "Un <b>faux</b> gras & un vrai **gras** → 3×8 ≈ 450 K€"
    _reader, text = text_of(ExecutiveBriefPdf.call(brief(final)))

    assert_includes text, "<b>faux</b>"
    assert_includes text, "→ 3×8 ≈ 450 K€"
  end

  # Un titre ne reste jamais seul en bas de page, ni son repère doré orphelin : quelle que soit la
  # longueur de ce qui précède, la page qui porte un titre porte aussi le début de sa section.
  test "a heading never ends a page" do
    (0..14).each do |extra|
      final = "#{'Préambule. ' * (extra * 5)}\n\n" +
              (1..8).map { |i| "## Section #{i}\n\n#{'Phrase répétée pour remplir la page. ' * 40}" }.join("\n\n")
      reader, = text_of(ExecutiveBriefPdf.call(brief(final)))

      reader.pages.each_with_index do |page, index|
        lines = page.text.lines.map(&:strip).reject(&:empty?)
        body = lines.reject { |line| line.start_with?("Cyrille PIERRE") || line.match?(%r{\A\d+ / \d+\z}) }
        assert_no_match(/\ASection \d+\z/, body.last.to_s, "titre orphelin en bas de la page #{index + 1} (préambule #{extra})")
      end
    end
  end

  test "a long note spans several numbered pages" do
    final = (1..40).map { |i| "## Section #{i}\n\n#{'Phrase répétée pour remplir la page. ' * 12}" }.join("\n\n")
    reader, text = text_of(ExecutiveBriefPdf.call(brief(final)))

    assert_operator reader.page_count, :>, 2
    assert_includes text, "1 / #{reader.page_count}"
  end
end
