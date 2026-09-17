require "prawn"

# La note de diagnostic dirigeant en PDF paginé A4, générée côté serveur : le rendu HTML
# (`document`) dépendait de l'impression du navigateur, et sur téléphone Cyrille n'obtenait
# qu'un long ruban. Même grammaire que ArticleFormatter — titres « ## »/« ### », paragraphes,
# listes, gras, liens — mais rendue en Prawn ; le texte du modèle est échappé avant toute
# interprétation, comme dans ArticleFormatter, pour qu'aucune balise ne puisse s'y glisser.
class ExecutiveBriefPdf
  FONTS_DIR = Rails.root.join("vendor/fonts/dejavu")
  INK = "1A2332"
  GOLD = "C9A961"
  MUTED = "5B6573"
  RULE = "DFE3E8"
  LINK_COLOR = "7A5C1E" # doré assombri : lisible en noir sur blanc, reconnaissable comme un lien

  BOLD = /\*\*(.+?)\*\*/
  LINK = /\[([^\[\]]+)\]\(([^()\s]+)\)/
  BULLET = /\A[-*]\s+/
  NUMBERED = /\A\d+\.\s+/

  def self.call(generation)
    new(generation).call
  end

  def initialize(generation)
    @generation = generation
  end

  def call
    Prawn::Document.new(page_size: "A4", margin: [54, 48, 60, 48], info: metadata) do |pdf|
      @pdf = pdf
      register_fonts
      header
      title
      body
      footer
    end.render
  end

  private

  attr_reader :generation, :pdf

  def metadata
    { Title: generation.display_title, Author: SiteIdentity::NAME, Creator: "cyrillepierre.com", CreationDate: Time.current }
  end

  def register_fonts
    pdf.font_families.update(
      "Serif" => { normal: FONTS_DIR.join("DejaVuSerif.ttf").to_s, bold: FONTS_DIR.join("DejaVuSerif-Bold.ttf").to_s },
      "Sans" => { normal: FONTS_DIR.join("DejaVuSans.ttf").to_s, bold: FONTS_DIR.join("DejaVuSans-Bold.ttf").to_s }
    )
    pdf.font("Serif")
    pdf.fill_color INK
  end

  def header
    top = pdf.cursor
    pdf.font("Sans") do
      pdf.text SiteIdentity::NAME, size: 12, style: :bold
      pdf.fill_color MUTED
      pdf.text "Manager de transition · Excellence opérationnelle · #{SiteIdentity::HOST.delete_prefix('https://')}",
               size: 8
      pdf.fill_color GOLD
      pdf.draw_text "CONFIDENTIEL", at: [pdf.bounds.right - 78, top - 9], size: 7.5, style: :bold,
                                    character_spacing: 1
      pdf.fill_color MUTED
      pdf.draw_text I18n.l(generation.updated_at.to_date, format: "%d/%m/%Y"), at: [pdf.bounds.right - 52, top - 22],
                                                                               size: 8
    end
    pdf.fill_color INK
    pdf.move_down 8
    pdf.stroke_color GOLD
    pdf.line_width 1.2
    pdf.stroke_horizontal_rule
    pdf.move_down 18
  end

  def title
    pdf.font("Sans") { pdf.text escape(generation.display_title), size: 17, style: :bold, leading: 3 }
    pdf.move_down 12
  end

  def body
    blocks.each { |block| render_block(block) }
  end

  def footer
    pdf.repeat(:all) do
      pdf.font("Sans") do
        pdf.fill_color MUTED
        pdf.stroke_color RULE
        pdf.line_width 0.5
        pdf.stroke_horizontal_line pdf.bounds.left, pdf.bounds.right, at: pdf.bounds.bottom - 14
        pdf.draw_text "#{SiteIdentity::NAME} · #{SiteIdentity::PHONE_DISPLAY} · #{SiteIdentity::EMAIL}",
                      at: [pdf.bounds.left, pdf.bounds.bottom - 28], size: 7.5
        pdf.fill_color INK
      end
    end
    pdf.number_pages "<page> / <total>", at: [pdf.bounds.right - 60, pdf.bounds.bottom - 28],
                                         width: 60, align: :right, size: 7.5, color: MUTED
  end

  def blocks
    generation.sections[:final].to_s.split(/\n\s*\n/).map(&:strip).reject(&:blank?)
  end

  def render_block(block)
    if block.start_with?("## ")
      heading(block.delete_prefix("## "), size: 11.5, rule: true)
    elsif block.start_with?("### ")
      heading(block.delete_prefix("### "), size: 10.5, rule: false)
    elsif list?(block)
      list(block)
    else
      paragraph(block)
    end
  end

  # Un repère doré identique devant chaque titre de section : le lecteur retrouve la structure
  # d'une page à l'autre sans lire.
  def heading(text, size:, rule:)
    pdf.move_down 6
    if rule
      pdf.stroke_color RULE
      pdf.line_width 0.5
      pdf.stroke_horizontal_rule
      pdf.move_down 9
    end
    pdf.fill_color GOLD
    pdf.fill_rectangle [pdf.bounds.left, pdf.cursor - 2], 4, size
    pdf.fill_color INK
    pdf.indent(10) do
      pdf.font("Sans") { pdf.text inline(text), size: size, style: :bold, inline_format: true }
    end
    pdf.move_down 5
  end

  def list?(block)
    lines = block.lines.map(&:strip)
    lines.all? { |l| l.match?(BULLET) } || lines.all? { |l| l.match?(NUMBERED) }
  end

  def list(block)
    lines = block.lines.map(&:strip)
    numbered = lines.first.match?(NUMBERED)
    lines.each_with_index do |line, index|
      marker = numbered ? "#{index + 1}." : "▪"
      item = line.sub(numbered ? NUMBERED : BULLET, "")
      pdf.indent(18) do
        pdf.fill_color GOLD
        pdf.draw_text marker, at: [-14, pdf.cursor - 9], size: numbered ? 10.5 : 9
        pdf.fill_color INK
        pdf.text inline(item), size: 10.5, leading: 3, inline_format: true, align: :justify
      end
      pdf.move_down 3
    end
    pdf.move_down 5
  end

  def paragraph(block)
    pdf.text inline(block.gsub("\n", " ")), size: 10.5, leading: 3.5, inline_format: true, align: :justify
    pdf.move_down 8
  end

  # Échappement d'abord, puis seulement le gras et les liens — la même précaution que le rendu HTML.
  def inline(fragment)
    escaped = escape(fragment.strip)
    linked = escaped.gsub(LINK) do
      %(<link href="#{Regexp.last_match(2)}"><color rgb="#{LINK_COLOR}"><u>#{Regexp.last_match(1)}</u></color></link>)
    end
    linked.gsub(BOLD, '<b>\1</b>')
  end

  def escape(text)
    text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
  end
end
