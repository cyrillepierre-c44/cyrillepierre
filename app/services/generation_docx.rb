require "zip"

# La note de diagnostic et la proposition commerciale en Word (.docx), pour que Cyrille les corrige
# à la main puis fasse lui-même le PDF (demande du 06/10/2026). Même grammaire que ExecutiveBriefPdf
# — titres « ## »/« ### », paragraphes, listes, gras, liens — mais rendue en vrais styles Word
# (Titre 1, Titre 2, listes à puces et numérotées), pour que la mise en forme survive aux corrections,
# et en français pour que le correcteur orthographique de Word s'applique. Le texte du modèle est
# échappé avant toute interprétation : aucune balise XML ne peut s'y glisser.
#
# Corps en Cambria, pas en Georgia : les chiffres « à l'ancienne » de Georgia descendaient sous la ligne,
# illisible dans un document chiffré. Cambria est livrée avec Office.
#
# Écrit à la main plutôt qu'avec une gem : un .docx n'est qu'une archive de quelques fichiers XML,
# et les gems de génération Word ne sont plus maintenues.
class GenerationDocx
  INK = "1A2332"
  GOLD = "C9A961"
  MUTED = "5B6573"
  LINK_COLOR = "7A5C1E"

  INLINE = /\[([^\[\]]+)\]\(([^()\s]+)\)|\*\*(.+?)\*\*/
  BULLET = /\A[-*]\s+/
  NUMBERED = /\A\d+\.\s+/

  # A4, marges de 2 cm, en vingtièmes de point. La marge haute est plus large : à 2 cm, le texte des
  # pages suivantes collait au filet doré de l'en-tête (rendu Word du 06/10/2026).
  PAGE_WIDTH = 11_906
  PAGE_HEIGHT = 16_838
  MARGIN = 1_134
  TOP_MARGIN = 1_700
  TEXT_WIDTH = PAGE_WIDTH - (2 * MARGIN)

  BULLET_LIST = 1
  # « 12 000 € » et « 50 % » ne se coupent pas en fin de ligne : Word coupait « 12 | 000 € HT ».
  NUMBER_SPACE = /(?<=\d) (?=\d{3}\b|€|%|K€|M€)/

  W = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" ' \
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"'.freeze

  def self.call(generation)
    new(generation).call
  end

  def initialize(generation)
    @generation = generation
    @links = []
    @numbered_lists = 0
  end

  def call
    body = blocks.map { |block| render_block(block) }.join
    document = document_xml(body)
    Zip::OutputStream.write_buffer do |zip|
      files(document).each do |name, content|
        zip.put_next_entry(name)
        zip.write(content)
      end
    end.string
  end

  private

  attr_reader :generation

  def blocks
    generation.sections[:final].to_s.split(/\n\s*\n/).map(&:strip).reject(&:blank?)
  end

  def files(document)
    {
      "[Content_Types].xml" => content_types_xml,
      "_rels/.rels" => root_rels_xml,
      "docProps/core.xml" => core_xml,
      "word/document.xml" => document,
      "word/styles.xml" => styles_xml,
      "word/numbering.xml" => numbering_xml,
      "word/header1.xml" => header_xml,
      "word/footer1.xml" => footer_xml,
      "word/_rels/document.xml.rels" => document_rels_xml
    }
  end

  def render_block(block)
    if block.start_with?("## ")
      paragraph(block.delete_prefix("## "), style: "Heading1")
    elsif block.start_with?("### ")
      paragraph(block.delete_prefix("### "), style: "Heading2")
    elsif list?(block)
      list(block)
    else
      paragraph(block.gsub("\n", " "))
    end
  end

  def list?(block)
    lines = block.lines.map(&:strip)
    lines.all? { |l| l.match?(BULLET) } || lines.all? { |l| l.match?(NUMBERED) }
  end

  # Chaque liste numérotée a sa propre numérotation, sinon Word poursuivrait la précédente.
  def list(block)
    lines = block.lines.map(&:strip)
    numbered = lines.first.match?(NUMBERED)
    num_id = numbered ? BULLET_LIST + (@numbered_lists += 1) : BULLET_LIST
    lines.map do |line|
      item = line.sub(numbered ? NUMBERED : BULLET, "")
      numbering = %(<w:numPr><w:ilvl w:val="0"/><w:numId w:val="#{num_id}"/></w:numPr>)
      paragraph(item, style: "ListParagraph", extra: numbering)
    end.join
  end

  def paragraph(text, style: nil, extra: "")
    style_tag = style ? %(<w:pStyle w:val="#{style}"/>) : ""
    "<w:p><w:pPr>#{style_tag}#{extra}</w:pPr>#{runs(text.strip)}</w:p>"
  end

  # Le texte entre deux marques (lien, gras) part tel quel ; seuls ces deux balisages sont lus.
  def runs(text)
    out = +""
    rest = text
    while (match = INLINE.match(rest))
      out << run(match.pre_match)
      out << (match[1] ? hyperlink(match[1], match[2]) : run(match[3], bold: true))
      rest = match.post_match
    end
    out << run(rest)
  end

  def run(text, bold: false)
    return "" if text.empty?

    props = bold ? "<w:rPr><w:b/></w:rPr>" : ""
    %(<w:r>#{props}<w:t xml:space="preserve">#{escape(unbreakable(text))}</w:t></w:r>)
  end

  def hyperlink(label, url)
    @links << url
    [
      %(<w:hyperlink r:id="rIdLink#{@links.size}"><w:r><w:rPr><w:rStyle w:val="Hyperlink"/></w:rPr>),
      %(<w:t xml:space="preserve">#{escape(label)}</w:t></w:r></w:hyperlink>)
    ].join
  end

  def unbreakable(text)
    text.gsub(NUMBER_SPACE, "\u00A0")
  end

  def escape(text)
    text.to_s.encode(xml: :text).gsub('"', "&quot;")
  end

  def document_xml(body)
    title = paragraph(generation.display_title.gsub("**", ""), style: "Title")
    section = [
      %(<w:sectPr><w:headerReference w:type="default" r:id="rIdHeader"/>),
      %(<w:footerReference w:type="default" r:id="rIdFooter"/>),
      %(<w:pgSz w:w="#{PAGE_WIDTH}" w:h="#{PAGE_HEIGHT}"/>),
      %(<w:pgMar w:top="#{TOP_MARGIN}" w:right="#{MARGIN}" w:bottom="#{MARGIN}" w:left="#{MARGIN}" ),
      %(w:header="567" w:footer="567" w:gutter="0"/></w:sectPr>)
    ].join
    xml(%(<w:document #{W}><w:body>), title, body, section, "</w:body></w:document>")
  end

  def header_xml
    date = I18n.l(generation.updated_at.to_date, format: "%d/%m/%Y")
    tab = %(<w:tabs><w:tab w:val="right" w:pos="#{TEXT_WIDTH}"/></w:tabs>)
    name = %(<w:rPr><w:b/><w:color w:val="#{INK}"/><w:sz w:val="24"/></w:rPr>)
    label = %(<w:rPr><w:b/><w:color w:val="#{GOLD}"/><w:spacing w:val="20"/></w:rPr>)
    rule = %(<w:pBdr><w:bottom w:val="single" w:sz="8" w:space="6" w:color="#{GOLD}"/></w:pBdr>)
    xml(
      %(<w:hdr #{W}><w:p><w:pPr><w:pStyle w:val="Header"/>#{tab}</w:pPr>),
      %(<w:r>#{name}<w:t>#{escape(SiteIdentity::NAME)}</w:t></w:r>),
      %(<w:r><w:tab/></w:r><w:r>#{label}<w:t>CONFIDENTIEL</w:t></w:r></w:p>),
      %(<w:p><w:pPr><w:pStyle w:val="Header"/>#{tab}#{rule}</w:pPr>),
      %(<w:r><w:t xml:space="preserve">#{escape(subtitle)}</w:t></w:r>),
      %(<w:r><w:tab/></w:r><w:r><w:t>#{date}</w:t></w:r></w:p></w:hdr>)
    )
  end

  def subtitle
    "Manager de transition · Excellence opérationnelle · #{SiteIdentity::HOST.delete_prefix('https://')}"
  end

  def footer_xml
    contacts = "#{SiteIdentity::NAME} · #{SiteIdentity::PHONE_DISPLAY} · #{SiteIdentity::EMAIL}"
    field = ->(code) { %(<w:fldSimple w:instr="#{code}"><w:r><w:t>1</w:t></w:r></w:fldSimple>) }
    xml(
      %(<w:ftr #{W}><w:p><w:pPr><w:pStyle w:val="Footer"/>),
      %(<w:tabs><w:tab w:val="right" w:pos="#{TEXT_WIDTH}"/></w:tabs></w:pPr>),
      %(<w:r><w:t xml:space="preserve">#{escape(contacts)}</w:t></w:r><w:r><w:tab/></w:r>),
      field.call("PAGE"), %(<w:r><w:t xml:space="preserve"> / </w:t></w:r>), field.call("NUMPAGES"),
      "</w:p></w:ftr>"
    )
  end

  def styles_xml
    xml(<<~XML.delete("\n"))
      <w:styles #{W}>
      <w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Cambria" w:hAnsi="Cambria" w:cs="Cambria"/>
      <w:color w:val="#{INK}"/><w:sz w:val="21"/><w:szCs w:val="21"/><w:lang w:val="fr-FR"/></w:rPr></w:rPrDefault>
      <w:pPrDefault><w:pPr><w:spacing w:after="160" w:line="300" w:lineRule="auto"/></w:pPr></w:pPrDefault>
      </w:docDefaults>
      <w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/>
      <w:pPr><w:jc w:val="both"/></w:pPr></w:style>
      <w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/>
      <w:next w:val="Normal"/><w:qFormat/><w:pPr><w:jc w:val="left"/><w:spacing w:before="120" w:after="240"/></w:pPr>
      <w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/><w:b/><w:sz w:val="34"/></w:rPr></w:style>
      <w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/>
      <w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:jc w:val="left"/>
      <w:pBdr><w:left w:val="single" w:sz="24" w:space="6" w:color="#{GOLD}"/></w:pBdr>
      <w:spacing w:before="280" w:after="100"/><w:outlineLvl w:val="0"/></w:pPr>
      <w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/><w:b/><w:sz w:val="23"/></w:rPr></w:style>
      <w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/>
      <w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:jc w:val="left"/>
      <w:spacing w:before="200" w:after="80"/><w:outlineLvl w:val="1"/></w:pPr>
      <w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/><w:b/><w:sz w:val="21"/></w:rPr></w:style>
      <w:style w:type="paragraph" w:styleId="ListParagraph"><w:name w:val="List Paragraph"/>
      <w:basedOn w:val="Normal"/><w:qFormat/><w:pPr><w:spacing w:after="60"/><w:ind w:left="360"/></w:pPr></w:style>
      <w:style w:type="paragraph" w:styleId="Header"><w:name w:val="header"/><w:basedOn w:val="Normal"/>
      <w:pPr><w:jc w:val="left"/><w:spacing w:after="0"/></w:pPr>
      <w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/><w:color w:val="#{MUTED}"/><w:sz w:val="16"/></w:rPr></w:style>
      <w:style w:type="paragraph" w:styleId="Footer"><w:name w:val="footer"/><w:basedOn w:val="Header"/></w:style>
      <w:style w:type="character" w:styleId="Hyperlink"><w:name w:val="Hyperlink"/>
      <w:rPr><w:color w:val="#{LINK_COLOR}"/><w:u w:val="single"/></w:rPr></w:style>
      </w:styles>
    XML
  end

  def numbering_xml
    numbered = (1..@numbered_lists).map do |i|
      [
        %(<w:num w:numId="#{BULLET_LIST + i}"><w:abstractNumId w:val="1"/>),
        %(<w:lvlOverride w:ilvl="0"><w:startOverride w:val="1"/></w:lvlOverride></w:num>)
      ].join
    end
    xml(
      %(<w:numbering #{W}>),
      abstract_list(0, "bullet", "▪", 260),
      abstract_list(1, "decimal", "%1.", 300),
      %(<w:num w:numId="#{BULLET_LIST}"><w:abstractNumId w:val="0"/></w:num>),
      *numbered,
      "</w:numbering>"
    )
  end

  def abstract_list(id, format, text, hanging)
    [
      %(<w:abstractNum w:abstractNumId="#{id}"><w:lvl w:ilvl="0"><w:start w:val="1"/>),
      %(<w:numFmt w:val="#{format}"/><w:lvlText w:val="#{text}"/><w:lvlJc w:val="left"/>),
      %(<w:pPr><w:ind w:left="360" w:hanging="#{hanging}"/></w:pPr>),
      %(<w:rPr><w:color w:val="#{GOLD}"/></w:rPr></w:lvl></w:abstractNum>)
    ].join
  end

  def content_types_xml
    part = ->(name, type) { %(<Override PartName="/#{name}" ContentType="#{type}"/>) }
    wml = "application/vnd.openxmlformats-officedocument.wordprocessingml"
    xml(
      %(<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">),
      %(<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>),
      %(<Default Extension="xml" ContentType="application/xml"/>),
      part.call("word/document.xml", "#{wml}.document.main+xml"),
      part.call("word/styles.xml", "#{wml}.styles+xml"),
      part.call("word/numbering.xml", "#{wml}.numbering+xml"),
      part.call("word/header1.xml", "#{wml}.header+xml"),
      part.call("word/footer1.xml", "#{wml}.footer+xml"),
      part.call("docProps/core.xml", "application/vnd.openxmlformats-package.core-properties+xml"),
      "</Types>"
    )
  end

  def root_rels_xml
    base = "http://schemas.openxmlformats.org"
    relation = lambda do |id, type, target|
      %(<Relationship Id="#{id}" Type="#{base}/#{type}" Target="#{target}"/>)
    end
    xml(
      %(<Relationships xmlns="#{base}/package/2006/relationships">),
      relation.call("rId1", "officeDocument/2006/relationships/officeDocument", "word/document.xml"),
      relation.call("rId2", "package/2006/relationships/metadata/core-properties", "docProps/core.xml"),
      "</Relationships>"
    )
  end

  def document_rels_xml
    type = ->(name) { "http://schemas.openxmlformats.org/officeDocument/2006/relationships/#{name}" }
    links = @links.each_with_index.map do |url, i|
      [
        %(<Relationship Id="rIdLink#{i + 1}" Type="#{type.call('hyperlink')}" ),
        %(Target="#{escape(url)}" TargetMode="External"/>)
      ].join
    end
    xml(
      %(<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">),
      %(<Relationship Id="rIdStyles" Type="#{type.call('styles')}" Target="styles.xml"/>),
      %(<Relationship Id="rIdNumbering" Type="#{type.call('numbering')}" Target="numbering.xml"/>),
      %(<Relationship Id="rIdHeader" Type="#{type.call('header')}" Target="header1.xml"/>),
      %(<Relationship Id="rIdFooter" Type="#{type.call('footer')}" Target="footer1.xml"/>),
      *links,
      "</Relationships>"
    )
  end

  def core_xml
    xml(
      %(<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" ),
      %(xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" ),
      %(xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">),
      %(<dc:title>#{escape(generation.display_title)}</dc:title>),
      %(<dc:creator>#{escape(SiteIdentity::NAME)}</dc:creator><dc:language>fr-FR</dc:language>),
      %(<dcterms:created xsi:type="dcterms:W3CDTF">#{Time.current.utc.iso8601}</dcterms:created>),
      "</cp:coreProperties>"
    )
  end

  def xml(*parts)
    %(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n#{parts.join})
  end
end
