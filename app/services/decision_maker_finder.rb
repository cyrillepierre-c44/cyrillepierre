# Cherche le décideur d'un site industriel là où il apparaît : articles de presse (inauguration,
# investissement), pages d'entreprise, extraits de profils. Trois recherches Tavily, une lecture
# par le modèle rapide qui ne fait que relever des noms, puis Ruby vérifie que chaque nom et sa
# phrase figurent mot pour mot dans la source citée — même chaîne anti-invention que l'outil
# d'analyse financière. Un nom sans source ne sort pas. Aucun email n'est deviné.
class DecisionMakerFinder
  MAX_CANDIDATES = 5

  INSTRUCTIONS = <<~PROMPT
    Tu relèves des NOMS DE PERSONNES dans des extraits de pages web, rien d'autre. On cherche qui dirige un
    site industriel précis (directeur d'usine, directeur de site, directeur industriel, directeur des
    opérations, responsable de production, DRH du site, ou le dirigeant si l'usine est la société elle-même).
    Réponds UNIQUEMENT par un tableau JSON, sans commentaire ni balise :
    [{"name": "Prénom Nom", "title": "fonction telle qu'écrite", "source": "<url de la source, copiée telle
    quelle>", "quote": "<la phrase exacte de la source qui contient le nom, copiée sans la modifier>"}]
    Règles : un nom n'est retenu que s'il figure tel quel dans le texte de la source ; la « quote » est un
    copier-coller, pas une reformulation ; ignore journalistes, élus, analystes, dirigeants d'autres sociétés,
    et les mandataires du siège s'ils ne sont pas rattachés au site ; cinq noms au plus, les plus
    probables d'abord ; tableau vide [] si rien de sûr.
  PROMPT

  Candidate = Struct.new(:name, :title, :source, :quote)

  def self.call(prospect)
    new(prospect).call
  end

  def initialize(prospect)
    @prospect = prospect
  end

  def call
    sources = collect_sources
    return "Aucune page trouvée par la recherche web pour « #{company_name} #{town} »." if sources.empty?

    candidates, rejected = verify(extract(sources), sources)
    render(candidates, rejected, sources)
  end

  private

  attr_reader :prospect

  def company_name
    prospect.company.to_s.split(/\s+[—–-]\s+|\(/).first.to_s.strip
  end

  def town
    prospect.company.to_s[%r{(?:site|usine|établissement)\s+d[e']\s*([^,(—/]+)}i, 1].to_s.strip
  end

  def queries
    base = [company_name, town].compact_blank.join(" ")
    ["directeur usine #{base}", "directeur de site #{base}", "#{base} directeur inauguration investissement"]
  end

  def collect_sources
    queries.flat_map { |q| Tavily.search(q, max_results: 5, raw: true) }
           .uniq(&:url).reject { |r| r.text.blank? }.first(12)
  end

  def extract(sources)
    listed = sources.each_with_index.map { |s, i| "SOURCE #{i + 1} — #{s.url}\n#{s.text}" }.join("\n\n")
    question = "ENTREPRISE : #{company_name}#{" — site de #{town}" if town.present?}\n\n#{listed}"
    reply = Mammouth.chat(model: Mammouth::DEFAULT_MODEL).with_instructions(INSTRUCTIONS).ask(question) { |_| nil }
    parse(reply.content.to_s)
  end

  def parse(text)
    json = text[/\[.*\]/m] || "[]"
    Array(JSON.parse(json)).map do |c|
      Candidate.new(c["name"].to_s.strip, c["title"].to_s.strip, c["source"].to_s.strip, c["quote"].to_s.strip)
    end
  rescue JSON::ParserError
    []
  end

  # Le modèle propose, Ruby dispose : la phrase doit être dans la source, le nom dans la phrase.
  def verify(candidates, sources)
    by_url = sources.index_by(&:url)
    kept, rejected = candidates.partition do |c|
      source = by_url[c.source]
      c.name.present? && source && normalize(source.text).include?(normalize(c.quote)) &&
        normalize(c.quote).include?(normalize(c.name))
    end
    [kept.uniq(&:name).first(MAX_CANDIDATES), rejected.size]
  end

  def normalize(text)
    I18n.transliterate(text.to_s).downcase.gsub(/\s+/, " ").strip
  end

  def render(candidates, rejected, sources)
    lines = ["DÉCIDEURS PROBABLES (recherche web Tavily, #{queries.size} requêtes, #{sources.size} pages lues) :"]
    if candidates.empty?
      dropped = " (#{rejected} proposition(s) sans source exacte, écartée(s))" if rejected.positive?
      lines << "- Aucun nom vérifiable dans les pages lues#{dropped}."
    else
      candidates.each do |c|
        lines << "- #{c.name} — #{c.title.presence || 'fonction non précisée'} — #{c.source}"
        lines << "  « #{c.quote.truncate(220)} »"
      end
      lines << "(#{rejected} proposition(s) écartée(s) faute de citation exacte.)" if rejected.positive?
    end
    lines << "À vérifier sur LinkedIn avant d'écrire : ces noms viennent d'extraits publics, pas d'un annuaire ; " \
             "aucun email n'est fourni."
    lines << "Pages consultées : #{sources.first(6).map(&:url).join(' · ')}"
    lines.join("\n")
  end
end
