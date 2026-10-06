require "test_helper"

# Le .docx s'ouvre dans Word pour être corrigé à la main (06/10/2026) : une archive mal formée ou un XML
# invalide, et Word propose de « réparer » le document, ce qui ne pardonne pas devant un client.
class GenerationDocxTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "docx-#{SecureRandom.hex(4)}@example.com", password: "password123")
    final = <<~MD.strip
      Madame,

      Ouverture avec **30,7 M€** et un [article](https://www.cyrillepierre.com/actus/1) <script>alert(1)</script>.

      ## Ce que je vous propose

      - Diagnostic express : 8 000 € HT
      - 50 % à la commande

      1. Premier
      2. Second

      ### Détail

      1. Encore un

      Cyrille PIERRE
    MD
    @generation = Generation.create!(user: user, kind: :commercial_proposal, title: "Proposition — Fonderie & Fils",
                                     status: :generated,
                                     output: "###VERSION_FINALE###\n#{final}\n\n###VERSION_COURTE###\nLe mail.")
    @entries = {}
    Zip::InputStream.open(StringIO.new(GenerationDocx.call(@generation))) do |zip|
      while (entry = zip.get_next_entry)
        @entries[entry.name] = zip.read.force_encoding("UTF-8")
      end
    end
  end

  def doc = Nokogiri::XML(@entries["word/document.xml"])
  def text_of(name) = Nokogiri::XML(@entries[name]).xpath("//w:t", "w" => W).map(&:text).join

  W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main".freeze

  test "the archive holds every part Word needs, all well-formed" do
    expected = %w[[Content_Types].xml _rels/.rels docProps/core.xml word/document.xml word/styles.xml
                  word/numbering.xml word/header1.xml word/footer1.xml word/_rels/document.xml.rels]
    assert_equal expected.sort, @entries.keys.sort
    @entries.each_value { |content| assert Nokogiri::XML(content, &:strict) }
  end

  test "the text is the final section only, escaped, with real Word styles" do
    text = text_of("word/document.xml")
    assert_includes text, "Proposition — Fonderie & Fils"
    assert_includes text, "<script>alert(1)</script>", "le texte est échappé, jamais interprété"
    assert_not_includes text, "Le mail."
    assert_not_includes text, "**"
    styles = doc.xpath("//w:pStyle/@w:val", "w" => W).map(&:value)
    assert_includes styles, "Title"
    assert_includes styles, "Heading1"
    assert_includes styles, "Heading2"
    assert_equal ["30,7\u00A0M€"], doc.xpath("//w:r[w:rPr/w:b]/w:t", "w" => W).map(&:text)
  end

  test "lists are real Word lists, each numbered list restarting at one" do
    num_ids = doc.xpath("//w:numId/@w:val", "w" => W).map(&:value)
    assert_equal %w[1 1 2 2 3], num_ids
    numbering = Nokogiri::XML(@entries["word/numbering.xml"])
    assert_equal 2, numbering.xpath("//w:startOverride", "w" => W).size
  end

  test "links point to their address, numbers do not break, and Word checks the spelling in French" do
    rels = @entries["word/_rels/document.xml.rels"]
    assert_includes rels, %(Target="https://www.cyrillepierre.com/actus/1" TargetMode="External")
    assert_includes text_of("word/document.xml"), "8 000 € HT"
    assert_includes text_of("word/document.xml"), "50 %"
    assert_includes @entries["word/styles.xml"], %(<w:lang w:val="fr-FR"/>)
    assert_includes text_of("word/header1.xml"), "CONFIDENTIEL"
    assert_includes @entries["word/footer1.xml"], %(w:instr="NUMPAGES")
  end

  # Ordre imposé par la norme (ECMA-376, CT_PPr et CT_RPr), limité aux balises que le générateur emploie.
  # Word 2007 refuse un fichier où elles sont dans le désordre ; Word 2016 l'accepte, d'où le piège.
  PPR_ORDER = %w[pStyle keepNext numPr pBdr tabs spacing ind jc outlineLvl].freeze
  RPR_ORDER = %w[rStyle rFonts b color spacing sz szCs u lang].freeze

  test "paragraph and run properties follow the order the standard imposes" do
    @entries.each do |name, content|
      xml = Nokogiri::XML(content)
      { "pPr" => PPR_ORDER, "rPr" => RPR_ORDER }.each do |node, order|
        xml.xpath("//w:#{node}", "w" => W).each do |props|
          children = props.element_children.map(&:name)
          assert (children - order).empty?, "#{name} : balise inconnue dans #{node} #{children}"
          assert_equal children.sort_by { |child| order.index(child) }, children, "#{name} : #{node} dans le désordre"
        end
      end
    end
  end

  # rubyzip 3 écrivait du Zip64 par défaut : Word 2007 refusait le fichier (06/10/2026). Un en-tête local
  # porte la version minimale requise en octets 4-5 ; 45 signale le Zip64, 20 est la version de base.
  test "the archive is a plain zip that Word 2007 can read, without Zip64" do
    bytes = GenerationDocx.call(@generation)
    assert_equal 20, bytes.byteslice(4, 2).unpack1("v")
    assert_not_includes bytes.b, [0x0001].pack("v") + [16].pack("v"), "pas de champ Zip64 dans les en-têtes"
  end
end

