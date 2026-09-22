require "net/http"

# Rassemble ce qu'une entreprise montre d'elle-même dans les sources publiques et gratuites, sans
# modèle de langage : l'annuaire officiel (identité, siège, effectif, dirigeants légaux, dernier
# exercice, établissements), le BODACC des douze derniers mois et les titres de presse. Le texte
# est composé en Ruby, donc chaque chiffre vient d'une réponse d'API — rien n'est inventé.
# Ce qu'aucune de ces sources ne donne : le directeur du site. Il se cherche à la main.
class ProspectEnricher
  TIMEOUT = 10
  ANNUAIRE = "https://recherche-entreprises.api.gouv.fr/search".freeze
  BODACC = "https://bodacc-datadila.opendatasoft.com/api/explore/v2.1/catalog/datasets/annonces-commerciales/records".freeze
  NEWS = "https://news.google.com/rss/search".freeze

  EFFECTIFS = {
    "NN" => "sans salarié", "00" => "0 salarié", "01" => "1 à 2", "02" => "3 à 5", "03" => "6 à 9",
    "11" => "10 à 19", "12" => "20 à 49", "21" => "50 à 99", "22" => "100 à 199", "31" => "200 à 249",
    "32" => "250 à 499", "41" => "500 à 999", "42" => "1 000 à 1 999", "51" => "2 000 à 4 999",
    "52" => "5 000 à 9 999", "53" => "10 000 et plus"
  }.freeze

  Result = Struct.new(:text, :siren)

  def self.call(prospect)
    new(prospect).call
  end

  def initialize(prospect)
    @prospect = prospect
  end

  def call
    company = fetch_company
    sections = [identity(company), bodacc(company), press]
    Result.new(sections.compact.join("\n\n"), company&.dig("siren"))
  end

  private

  attr_reader :prospect

  # « MAPEI France — usine de Saint-Vulbas (01) » : on cherche « MAPEI France ». Le SIREN, s'il est
  # déjà connu, prime sur le nom.
  def query_name
    prospect.company.to_s.split(/\s+[—–-]\s+|\(/).first.to_s.strip
  end

  def fetch_company
    q = prospect.siren.presence || query_name
    return nil if q.blank?

    json = get_json(URI("#{ANNUAIRE}?q=#{CGI.escape(q)}&per_page=3"))
    json["results"].to_a.first
  end

  def identity(company)
    return "IDENTITÉ (annuaire officiel) : aucune société trouvée pour « #{query_name} »." if company.nil?

    siege = company["siege"] || {}
    lines = ["IDENTITÉ (annuaire officiel, recherche-entreprises.api.gouv.fr) :"]
    category = company["categorie_entreprise"] || "catégorie non précisée"
    lines << "- #{company['nom_complet']} · SIREN #{company['siren']} · #{category} · " \
             "créée le #{french_date(company['date_creation'])}"
    lines << "- Siège : #{siege['adresse']}" if siege["adresse"].present?
    lines << "- Activité principale : #{company['activite_principale']}" if company["activite_principale"].present?
    effectif = EFFECTIFS[company["tranche_effectif_salarie"].to_s]
    lines << "- Effectif (tranche) : #{effectif} salariés" if effectif
    etabs = Array(company["matching_etablissements"]).map { |e| e["libelle_commune"] }.compact.uniq
    if etabs.any?
      lines << "- Établissements (#{company['nombre_etablissements_ouverts']} ouverts) : #{etabs.join(', ')}"
    end
    lines.concat(finances(company["finances"]))
    lines.concat(leaders(company["dirigeants"]))
    lines.join("\n")
  end

  # L'annuaire ne donne qu'un exercice : un signal de situation, pas une tendance.
  def finances(data)
    return [] if data.blank?

    year, values = data.max_by { |y, _| y.to_s }
    ca = values["ca"]
    rn = values["resultat_net"]
    return [] if ca.nil? && rn.nil?

    parts = []
    parts << "chiffre d'affaires #{money(ca)}" if ca
    parts << "résultat net #{money(rn)}" if rn
    parts << "(#{(rn.to_f / ca * 100).round(1)} % du CA)" if ca && rn && ca.to_i != 0
    ["- Dernier exercice publié (#{year}) : #{parts.join(', ')} — un seul exercice, pas de tendance"]
  end

  # Les représentants légaux (souvent la holding ou le siège), pas le directeur du site.
  def leaders(list)
    people = Array(list).reject { |d| d["qualite"].to_s.match?(/commissaire/i) }
                        .select { |d| d["nom"] || d["denomination"] }
                        .map { |d| [[d["prenoms"], d["nom"]].compact.join(" ").strip, d["qualite"]] }
    return [] if people.empty?

    listed = people.first(5).map { |name, role| "#{name} (#{role})" }.join(" · ")
    ["- Représentants légaux (pas le directeur du site) : #{listed}"]
  end

  def bodacc(company)
    return nil if company.nil?

    since = (Date.current - 365).iso8601
    where = CGI.escape(%(registre="#{company['siren']}" AND dateparution>="#{since}"))
    query = "where=#{where}&order_by=dateparution%20desc&limit=10&select=dateparution,familleavis_lib"
    json = get_json(URI("#{BODACC}?#{query}"))
    rows = json["results"].to_a
    return "BODACC (12 derniers mois) : aucun avis." if rows.empty?

    lines = rows.map { |r| "- #{french_date(r['dateparution'])} : #{r['familleavis_lib']}" }
    "BODACC (12 derniers mois, #{json['total_count']} avis) :\n#{lines.join("\n")}"
  rescue StandardError => e
    "BODACC : lecture impossible (#{e.class})."
  end

  def press
    q = query_name
    return nil if q.blank?

    xml = get_body(URI("#{NEWS}?q=#{CGI.escape(%("#{q}"))}&hl=fr&gl=FR&ceid=FR:fr"))
    items = xml.scan(%r{<item>(.*?)</item>}m).map(&:first).filter_map do |item|
      title = item[%r{<title>(.*?)</title>}m, 1].to_s.gsub(/<!\[CDATA\[|\]\]>/, "").strip
      date = item[%r{<pubDate>(.*?)</pubDate>}m, 1]
      link = item[%r{<link>(.*?)</link>}m, 1].to_s.strip
      parsed = date && begin
        Time.zone.parse(date)
      rescue StandardError
        nil
      end
      next if parsed.nil? || parsed < 365.days.ago

      "- #{parsed.strftime('%d/%m/%Y')} : #{title} — #{link}"
    end
    return "PRESSE (12 derniers mois, titres seulement) : rien trouvé sur « #{q} »." if items.empty?

    "PRESSE (12 derniers mois, titres seulement — lire l'article avant de citer) :\n#{items.first(5).join("\n")}"
  rescue StandardError => e
    "PRESSE : lecture impossible (#{e.class})."
  end

  def get_json(uri)
    JSON.parse(get_body(uri))
  end

  def get_body(uri)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT,
                                                   read_timeout: TIMEOUT) do |http|
      http.get(uri.request_uri, { "User-Agent" => "cyrillepierre.com prospect enrichment" })
    end
    raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    response.body.to_s.force_encoding(Encoding::UTF_8)
  end

  def french_date(value)
    Date.parse(value.to_s).strftime("%d/%m/%Y")
  rescue ArgumentError, TypeError
    value.to_s.presence || "date inconnue"
  end

  def money(value)
    n = value.to_f
    if n.abs >= 1_000_000 then "#{format('%.1f', n / 1_000_000).tr('.', ',')} M€"
    elsif n.abs >= 1_000 then "#{(n / 1_000).round} K€"
    else "#{n.round} €"
    end
  end
end
