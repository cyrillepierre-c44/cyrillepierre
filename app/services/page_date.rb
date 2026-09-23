# Date d'une page web, sans rien deviner. Deux sources, et rien d'autre : l'adresse quand elle
# porte la date (`/2022/01/05/`, `-21022024`, `20061017…pdf`, `2024-02-12`), ou une date lue dans la page, à
# condition qu'elle y figure sous l'une des graphies courantes — le modèle qui l'a relevée peut
# s'être trompé de champ, pas Ruby. Une page qui ne montre aucune date reste « non datée » :
# c'est une information en soi, pas une valeur par défaut.
#
# Pourquoi : le 23/09/2026, le chercheur de décideur a présenté comme directeur industriel de
# MAPEI France un homme parti en janvier 2017, sur la foi d'un article de presse de 2015 cité sans
# sa date. Un nom sans la date de sa source ne dit pas qui est en poste, il dit qui l'a été.
module PageDate
  MONTHS_FR = %w[janvier février mars avril mai juin juillet août septembre octobre novembre décembre].freeze
  MONTHS_EN = %w[January February March April May June July August September October November December].freeze

  # Les huit chiffres collés se lisent d'abord année-mois-jour (`20061017compterendu.pdf`), puis
  # jour-mois-année (`-21022024`) : une lecture qui ne donne pas une date valide passe à la suivante.
  URL_PATTERNS = [
    %r{/(?<y>20\d{2})/(?<m>\d{2})/(?<d>\d{2})(?:/|$)},
    /(?<![0-9])(?<y>20\d{2})-(?<m>\d{2})-(?<d>\d{2})(?![0-9])/,
    /(?<![0-9])(?<y>20\d{2})(?<m>\d{2})(?<d>\d{2})(?![0-9])/,
    /(?<![0-9])(?<d>\d{2})(?<m>\d{2})(?<y>20\d{2})(?![0-9])/
  ].freeze

  def self.from_url(url)
    path = URI(url.to_s).path.to_s
    URL_PATTERNS.each do |pattern|
      m = path.match(pattern) or next
      date = build(m[:y], m[:m], m[:d])
      return date if date
    end
    nil
  rescue URI::InvalidURIError
    nil
  end

  # La date dite par le modèle (« AAAA-MM-JJ ») ne vaut que si la page la contient réellement.
  def self.read(text_from_model, page_text)
    date = Date.iso8601(text_from_model.to_s)
    return nil if date > Date.current

    mentioned?(date, page_text) ? date : nil
  rescue Date::Error
    nil
  end

  def self.mentioned?(date, text)
    return false if date.nil? || text.blank?

    haystack = normalize(text)
    spellings(date).any? { |spelling| haystack.include?(normalize(spelling)) }
  end

  def self.spellings(date)
    day = date.day
    year = date.year
    fr = MONTHS_FR[date.month - 1]
    en = MONTHS_EN[date.month - 1]
    dd = format("%02d", day)
    mm = format("%02d", date.month)
    [
      "#{dd}/#{mm}/#{year}", "#{day}/#{mm}/#{year}", "#{day}/#{date.month}/#{year}", "#{dd}.#{mm}.#{year}",
      date.iso8601, "#{day} #{fr} #{year}", "#{dd} #{fr} #{year}", ("1er #{fr} #{year}" if day == 1),
      "#{day} #{en} #{year}", "#{en} #{day}, #{year}"
    ].compact
  end

  def self.build(year, month, day)
    Date.new(year.to_i, month.to_i, day.to_i)
  rescue Date::Error
    nil
  end

  def self.normalize(text)
    I18n.transliterate(text.to_s).downcase.gsub(/\s+/, " ")
  end
end
