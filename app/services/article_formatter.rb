# Rend en HTML le markdown restreint que le prompt d'article demande au modèle : titres de
# niveau 2 et 3, paragraphes, listes et gras. Rien d'autre.
#
# Pas de gem markdown pour ce seul besoin, et surtout : le texte vient d'un LLM. Ici il est
# échappé AVANT toute transformation, donc aucune balise ne peut sortir du modèle vers la page.
# Un rendu markdown complet accepterait le HTML brut et rouvrirait cette porte.
class ArticleFormatter
  HEADINGS = { "### " => "h3", "## " => "h2" }.freeze
  BOLD = /\*\*(.+?)\*\*/
  LINK = /\[([^\[\]]+)\]\(([^()\s]+)\)/
  # Un lien vient du modèle : sa cible est validée, jamais recopiée telle quelle. Seules deux
  # formes passent — un chemin interne, ou une URL https. Tout le reste (javascript:, data:,
  # //hote-externe) retombe en texte simple, sans lien.
  INTERNAL_PATH = %r{\A/[^/\\]\S*\z}
  EXTERNAL_URL = %r{\Ahttps://[^\s"'<>]+\z}
  BULLET = /\A[-*]\s+/
  NUMBERED = /\A\d+\.\s+/

  def self.call(text)
    new(text).to_html
  end

  # Version sans balisage, pour les extraits de liste et les meta descriptions : sans elle
  # les « ## » du markdown se retrouvaient dans l'extrait affiché sous le titre.
  def self.plain_text(text)
    text.to_s
        .gsub(/^#{Regexp.union(HEADINGS.keys)}/, "")
        .gsub(LINK, '\1')
        .gsub(BOLD, '\1')
        .gsub(/^[-*]\s+/, "")
        .squish
  end

  def initialize(text)
    @text = text.to_s
  end

  def to_html
    blocks.map { |block| render(block) }.join("\n").html_safe
  end

  private

  attr_reader :text

  def blocks
    text.split(/\n\s*\n/).map(&:strip).reject(&:blank?)
  end

  def render(block)
    heading(block) || list(block) || paragraph(block)
  end

  def heading(block)
    prefix, tag_name = HEADINGS.find { |marker, _| block.start_with?(marker) }
    return if prefix.nil?

    "<#{tag_name}>#{inline(block.delete_prefix(prefix))}</#{tag_name}>"
  end

  def list(block)
    lines = block.lines.map(&:strip)
    marker = [BULLET, NUMBERED].find { |pattern| lines.all? { |line| line.match?(pattern) } }
    return if marker.nil?

    items = lines.map { |line| "<li>#{inline(line.sub(marker, ''))}</li>" }
    "<#{marker == BULLET ? 'ul' : 'ol'}>#{items.join}</#{marker == BULLET ? 'ul' : 'ol'}>"
  end

  def paragraph(block)
    "<p>#{inline(block).gsub("\n", '<br>')}</p>"
  end

  # L'échappement se fait ici, en bout de chaîne, sur le texte brut du modèle. Le gras est
  # réintroduit après coup à partir des astérisques, qui ont survécu à l'échappement.
  def inline(fragment)
    escaped = ERB::Util.html_escape(fragment.strip)
    linked = escaped.gsub(LINK) { link_tag(Regexp.last_match(1), Regexp.last_match(2)) }
    linked.gsub(BOLD, '<strong>\1</strong>')
  end

  def link_tag(label, href)
    return label unless href.match?(INTERNAL_PATH) || href.match?(EXTERNAL_URL)

    rel = href.match?(EXTERNAL_URL) ? ' rel="noopener nofollow"' : ""
    %(<a href="#{href}"#{rel}>#{label}</a>)
  end
end
