# Cherche le décideur d'un site industriel là où il apparaît : articles de presse (inauguration,
# investissement), pages d'entreprise, extraits de profils. Trois recherches Tavily, une lecture
# par le modèle rapide qui ne fait que relever des noms et la date de la page, puis Ruby vérifie
# que chaque nom et sa phrase figurent mot pour mot dans la source citée, et que la date y est
# écrite — même chaîne anti-invention que l'outil d'analyse financière. Un nom sans source ne
# sort pas. Aucun email n'est deviné.
#
# Chaque nom sort avec la date de sa source, et une source de plus de deux ans ne fait plus
# partie des « probables » : elle dit qui a dirigé, pas qui dirige. Le 23/09/2026, un article
# de 2015 avait fait présenter comme directeur industriel de MAPEI France un homme parti
# en janvier 2017, et la vérification LinkedIn n'avait servi qu'à le découvrir.
class DecisionMakerFinder
  MAX_CANDIDATES = 5
  STALE_AFTER = 2.years

  INSTRUCTIONS = <<~PROMPT
    Tu relèves des NOMS DE PERSONNES dans des extraits de pages web, rien d'autre. On cherche qui dirige un
    site industriel précis (directeur d'usine, directeur de site, directeur industriel, directeur des
    opérations, responsable de production, DRH du site, ou le dirigeant si l'usine est la société elle-même).
    Réponds UNIQUEMENT par un tableau JSON, sans commentaire ni balise :
    [{"name": "Prénom Nom", "title": "fonction telle qu'écrite", "source": "<url de la source, copiée telle
    quelle>", "quote": "<la phrase exacte de la source qui contient le nom, copiée sans la modifier>",
    "date": "<date de publication de la page, AAAA-MM-JJ, telle qu'elle est écrite dans la page ; null si la
    page n'en montre aucune>"}]
    Règles : un nom n'est retenu que s'il figure tel quel dans le texte de la source ; la « quote » est un
    copier-coller, pas une reformulation ; ignore journalistes, élus, analystes et dirigeants d'autres
    sociétés. La « date » est celle de l'article ou de la publication, jamais une date citée dans le corps
    du texte (inauguration prévue, exercice comptable) ni celle d'un autre article listé en marge ; dans le
    doute, null. Quand le poste de direction du site est lui-même vacant (annonce d'emploi), relève le supérieur
    auquel l'annonce rattache le poste s'il est nommé, et à défaut le directeur général ou le directeur
    industriel de la société, en le disant dans « title » (« directeur général de la société — pas le site »).
    Cinq noms au plus, les plus probables d'abord ; tableau vide [] si rien de sûr.
  PROMPT

  Candidate = Struct.new(:name, :title, :source, :quote, :date_text, :dated_on) do
    def stale?
      dated_on.present? && dated_on < STALE_AFTER.ago.to_date
    end
  end

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
      Candidate.new(c["name"].to_s.strip, c["title"].to_s.strip, c["source"].to_s.strip, c["quote"].to_s.strip,
                    c["date"].to_s.strip)
    end
  rescue JSON::ParserError
    []
  end

  # Le modèle propose, Ruby dispose : la phrase doit être dans la source, le nom dans la phrase, et la
  # date écrite dans la page (ou portée par son adresse) — sinon la page reste « non datée ».
  def verify(candidates, sources)
    by_url = sources.index_by(&:url)
    kept, rejected = candidates.partition do |c|
      source = by_url[c.source]
      c.name.present? && source && normalize(source.text).include?(normalize(c.quote)) &&
        normalize(c.quote).include?(normalize(c.name))
    end
    dates = page_dates(kept, by_url)
    kept.each { |c| c.dated_on = dates[c.source] }
    [kept.uniq(&:name).first(MAX_CANDIDATES), rejected.size]
  end

  # La date appartient à la page, pas au nom : la première date vérifiée que le modèle a lue sur
  # cette page vaut pour tous les noms qui en viennent, l'adresse sert de repli.
  def page_dates(candidates, by_url)
    candidates.group_by(&:source).transform_values do |from_page|
      url = from_page.first.source
      from_page.lazy.filter_map { |c| PageDate.read(c.date_text, by_url[url].text) }.first || PageDate.from_url(url)
    end
  end

  def normalize(text)
    I18n.transliterate(text.to_s).downcase.gsub(/\s+/, " ").strip
  end

  def render(candidates, rejected, sources)
    lines = ["DÉCIDEURS PROBABLES (recherche web Tavily, #{queries.size} requêtes, #{sources.size} pages lues) :"]
    current, stale = candidates.partition { |c| !c.stale? }
    if current.empty?
      dropped = " (#{rejected} proposition(s) sans source exacte, écartée(s))" if rejected.positive?
      lines << "- Aucun nom vérifiable dans une page récente#{dropped}."
    else
      ordered(current).each do |c|
        lines << "- #{c.name} — #{c.title.presence || 'fonction non précisée'} — #{c.source} — #{dating(c)}"
        lines << "  « #{c.quote.truncate(220)} »"
      end
      lines << "(#{rejected} proposition(s) écartée(s) faute de citation exacte.)" if rejected.positive?
    end
    if stale.any?
      lines << "TROP ANCIENS pour dire qui est en poste aujourd'hui (source de plus de deux ans) :"
      stale.sort_by(&:dated_on).reverse_each do |c|
        lines << "- #{c.name} — #{c.title.presence || 'fonction non précisée'} — #{c.source} — #{dating(c)}"
      end
    end
    lines << "À vérifier sur LinkedIn avant d'écrire : ces noms viennent d'extraits publics, pas d'un annuaire ; " \
             "une page datée dit qui était en poste ce jour-là, pas aujourd'hui ; aucun email n'est fourni."
    lines << "Pages consultées : #{sources.first(6).map(&:url).join(' · ')}"
    lines.join("\n")
  end

  # Les pages datées d'abord, de la plus récente à la plus ancienne ; les non datées ensuite,
  # dans l'ordre de confiance du modèle.
  def ordered(candidates)
    dated, undated = candidates.partition(&:dated_on)
    dated.sort_by(&:dated_on).reverse + undated
  end

  def dating(candidate)
    return "page non datée, vérifier d'abord de quand elle date" if candidate.dated_on.nil?

    age = ((Date.current - candidate.dated_on) / 365.25).floor
    ago = age >= 1 ? " (il y a #{age} an#{'s' if age > 1})" : ""
    "source du #{candidate.dated_on.strftime('%d/%m/%Y')}#{ago}"
  end
end
