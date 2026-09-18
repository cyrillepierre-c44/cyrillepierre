# Relit une note chiffre par chiffre contre ses sources, sans modèle de langage : chaque nombre du
# texte — montant, pourcentage, année, mois daté, effectif — doit exister dans les sources, à
# l'arrondi et à l'unité près (« €30.7m » vaut « 30 729 278 € », « November 2023 » vaut
# « novembre 2023 »). Ce que l'audit signale, ContentGenerator le fait corriger par le modèle ;
# ce qu'il ne signale pas n'a plus besoin d'être relu à la main. Déterministe et gratuit.
#
# Un chiffre calculé (« un point de chiffre d'affaires vaut 307 K€ ») n'est dans aucune source :
# il ne passe que si le modèle en donne la formule, que `supports?` recalcule à partir de chiffres
# eux-mêmes sourcés. Le modèle affirme, Ruby vérifie.
class FigureAudit
  Figure = Struct.new(:raw, :value, :kind) do
    def exact? = %i[year date].include?(kind)
  end

  RELATIVE_TOLERANCE = 0.03
  PERCENT_POINT_TOLERANCE = 0.45
  # Un petit entier nu (« three points », « 5 questions », « 8 jours ») n'est pas un chiffre à sourcer.
  SMALL_UNITLESS = 12
  YEARS = 1990..2035

  MONTHS = {
    "janvier" => 1, "février" => 2, "mars" => 3, "avril" => 4, "mai" => 5, "juin" => 6, "juillet" => 7,
    "août" => 8, "septembre" => 9, "octobre" => 10, "novembre" => 11, "décembre" => 12,
    "january" => 1, "february" => 2, "march" => 3, "april" => 4, "may" => 5, "june" => 6, "july" => 7,
    "august" => 8, "september" => 9, "october" => 10, "november" => 11, "december" => 12
  }.freeze

  NUMBER = /
    (?<![\d.,])
    (?<currency>[€$]\s?)?
    (?<num>\d{1,3}(?:[ \u202F\u00A0]\d{3})+(?:[.,]\d+)?|\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:[.,]\d+)?)
    \s?(?<unit>%|Md€|M€|K€|k€|€|bn\b|milliards?\b|millions?\b|m\b|k\b|M\b|K\b)?
    (?!\d|[.,]\d)
  /x

  MONTH_YEAR = /\b(?<month>#{MONTHS.keys.join('|')})\s+(?<year>(?:19|20)\d{2})\b/i

  # Ce qui porte des nombres sans rien affirmer : adresses, numéros de liste, marqueurs de
  # section, identifiants du catalogue, durées de lecture ou d'entretien.
  NOISE = [
    %r{https?://\S+},
    /^\s*(?:#+\s*)?\d+\.\s/,
    /###[A-Z_]+###/,
    /\bN°\s?\d+/,
    /\b\d+[- ]?(?:minutes?|min|heures?|hours?|pages?|mots|words)\b/i
  ].freeze

  def self.call(note:, sources:)
    new(sources).unsourced(note)
  end

  def initialize(sources)
    @sources = Array(sources).compact.join("\n")
    @source_figures = figures_in(@sources)
  end

  # Les chiffres de la note absents des sources, dans l'ordre d'apparition, sans doublon.
  def unsourced(note)
    figures_in(note.to_s).reject { |figure| sourced?(figure) }.uniq(&:raw)
  end

  def sourced?(figure)
    @source_figures.any? { |candidate| matches?(figure, candidate) }
  end

  # Le texte désigne-t-il ce chiffre ? Sert à retrouver la ligne de journal du modèle qui le concerne.
  def same_figure?(figure, text)
    figures_in(text.to_s).any? { |candidate| matches?(figure, candidate) }
  end

  # Recalcule « 30,7 M€ × 1 % » : la formule ne soutient le chiffre que si elle se lit, que chacun de
  # ses opérandes est sourcé et que son résultat tombe sur le chiffre (en ratio ou en pour cent).
  def supports?(figure, formula)
    result = evaluate(formula)
    return false if result.nil?

    candidates = figure.kind == :percent ? [result, result * 100] : [result]
    candidates.any? { |value| matches?(figure, Figure.new(nil, value, figure.kind)) }
  end

  def evaluate(formula)
    expression = formula.to_s.tr("×x*", "***").tr("÷", "/").gsub(/[−–]/, "-")
    operands = figures_in(expression)
    return nil if operands.empty? || operands.any? { |operand| !constant?(operand) && !sourced?(operand) }

    compute(expression.gsub(NUMBER) { operand_value(Regexp.last_match).to_s })
  end

  private

  # Les constantes d'un calcul ne sont dans aucune source : « un point » (1 %), les douze mois, les
  # jours de l'année. Tout autre pourcentage ou nombre doit venir des sources.
  def constant?(operand)
    (operand.kind == :percent && operand.value <= 1) ||
      (operand.kind == :count && [100.0, 365.0, 1000.0].include?(operand.value))
  end

  def operand_value(match)
    value = build(match[0], match[:currency].to_s, match[:num], match[:unit].to_s, ignore_small: false)&.value
    match[:unit] == "%" ? value.to_f / 100 : value.to_f
  end

  # Le calcul est borné aux quatre opérations et aux parenthèses : la chaîne est déjà réduite à des
  # nombres décimaux, aucun autre caractère n'y survit avant l'évaluation.
  def compute(expression)
    cleaned = expression.gsub(%r{[^\d.()+\-*/\s]}, "")
    return nil if cleaned.strip.empty?

    tokens = cleaned.scan(%r{\d+(?:\.\d+)?|[()+\-*/]})
    result, rest = parse_sum(tokens)
    rest.empty? ? result : nil
  rescue ZeroDivisionError, TypeError, NoMethodError
    nil
  end

  def parse_sum(tokens)
    value, tokens = parse_product(tokens)
    while %w[+ -].include?(tokens.first)
      op = tokens.shift
      rhs, tokens = parse_product(tokens)
      value = op == "+" ? value + rhs : value - rhs
    end
    [value, tokens]
  end

  def parse_product(tokens)
    value, tokens = parse_atom(tokens)
    while %w[* /].include?(tokens.first)
      op = tokens.shift
      rhs, tokens = parse_atom(tokens)
      value = op == "*" ? value * rhs : value / rhs
    end
    [value, tokens]
  end

  def parse_atom(tokens)
    token = tokens.shift
    if token == "("
      value, tokens = parse_sum(tokens)
      tokens.shift == ")" or raise TypeError
      [value, tokens]
    elsif token == "-"
      value, tokens = parse_atom(tokens)
      [-value, tokens]
    else
      [Float(token), tokens]
    end
  end

  def figures_in(text)
    cleaned = NOISE.reduce(text) { |acc, pattern| acc.gsub(pattern, " ") }
    dates = cleaned.to_enum(:scan, MONTH_YEAR).map do
      match = Regexp.last_match
      Figure.new(match[0], (match[:year].to_i * 100) + MONTHS.fetch(match[:month].downcase), :date)
    end
    numbers = cleaned.to_enum(:scan, NUMBER).filter_map do
      match = Regexp.last_match
      build(match[0].strip, match[:currency].to_s, match[:num], match[:unit].to_s)
    end
    dates + numbers
  end

  def build(raw, currency, num, unit, ignore_small: true)
    value = numeric(num)
    kind = kind_for(num, unit, currency)
    return nil if ignore_small && kind == :count && unit.empty? && value <= SMALL_UNITLESS

    Figure.new(raw, value * multiplier(unit), kind)
  end

  # « 30 729 278 », « 30,729,278 », « 22,5 » et « 22.5 » : un séparateur suivi d'exactement trois
  # chiffres est un séparateur de milliers s'il y en a plusieurs ou si c'est une virgule.
  def numeric(num)
    digits = num.gsub(/[   ]/, "")
    return Float(digits) unless digits.match?(/[.,]/)

    head, separator, tail = digits.rpartition(/[.,]/)
    thousands = tail.length == 3 && (head.match?(/[.,]/) || separator == ",")
    head = head.delete(".,")
    Float(thousands ? head + tail : "#{head}.#{tail}")
  end

  def kind_for(num, unit, currency)
    return :percent if unit == "%"
    return :amount if unit.include?("€") || currency.present?
    return :year if unit.empty? && num.match?(/\A(?:19|20)\d{2}\z/) && YEARS.cover?(num.to_i)

    :count
  end

  def multiplier(unit)
    case unit
    when /\Abn\z/, /\AMd€\z/, /milliard/ then 1_000_000_000
    when /\AM€\z/, /\A[mM]\z/, /million/ then 1_000_000
    when /\A[kK]€\z/, /\A[kK]\z/ then 1_000
    else 1
    end
  end

  # Un montant peut être écrit sans unité dans la source (« 307 K€ » vs « 307 »), un effectif avec
  # « personnes » : montants et nombres se comparent entre eux, jamais un pourcentage à un montant,
  # et une année ou un mois daté ne se compare qu'à l'identique.
  def matches?(figure, candidate)
    return figure.value == candidate.value if figure.exact? || candidate.exact?
    return false if (figure.kind == :percent) != (candidate.kind == :percent)
    return (figure.value - candidate.value).abs <= PERCENT_POINT_TOLERANCE if figure.kind == :percent

    close?(figure.value, candidate.value)
  end

  def close?(value, candidate)
    return value == candidate if value.zero? || candidate.zero?

    (value - candidate).abs <= candidate.abs * RELATIVE_TOLERANCE
  end
end
