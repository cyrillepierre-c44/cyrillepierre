require "test_helper"

# L'audit relit une note en anglais contre une analyse en français : mêmes chiffres, autres
# unités, autres séparateurs. Ce qu'il laisse passer n'a plus à être relu à la main, donc chaque
# tolérance ci-dessous est un choix, pas un hasard.
class FigureAuditTest < ActiveSupport::TestCase
  SOURCE = <<~TXT
    Le chiffre d'affaires passe de 26,8 M€ (2021) à 30 729 278 € en 2025, soit +13,9 % sur la dernière
    année. Frais de personnel 42,7 % du CA contre 39,6 % en 2021. Stocks matières 122 jours d'achats.
    Nouvelle ligne de 12,8 M€ inaugurée en novembre 2023. Résultat net -2,7 M€. Effectif 400 personnes.
    Trésorerie 0,9 M€. DN/EBITDA 67,8x. Liquidité 0,68. Marché européen estimé à ~25 Md€.
  TXT

  def unsourced(note)
    FigureAudit.call(note: note, sources: SOURCE).map(&:raw)
  end

  test "a figure written in another language, unit or rounding is still sourced" do
    note = "Revenue rose from €26.8m in 2021 to €30.7m in 2025, up 14% on the year. Labour costs ran at " \
           "42.7% of revenue against 39.6%. Stock covers 122 days. The €12.8m line opened in November 2023. " \
           "A net loss of -2.7 M€, 400 people, cash of €900k, 67.8x net debt to EBITDA, 30,729,278 euros, " \
           "a €25bn market."

    assert_empty unsourced(note)
  end

  test "an invented amount, percentage, year or dated month is flagged once" do
    note = "Revenue of €30.7m and €4.9m of savings, 57% of labour, back in 2019, since November 2025, " \
           "and again €4.9m."

    assert_equal ["November 2025", "€4.9m", "57%", "2019"], unsourced(note)
  end

  test "a rounding beyond the tolerance is flagged" do
    assert_equal ["€32m"], unsourced("Revenue of €32m.")
    assert_equal ["44%"], unsourced("Labour at 44% of revenue.")
  end

  test "a percentage never matches an amount and a year never matches a rounded neighbour" do
    assert_equal ["122%"], unsourced("Stock at 122%.")
    assert_equal ["2024"], unsourced("Since 2024, revenue is €30.7m.")
  end

  test "small bare integers, list numbers, links, catalogue ids and durations are ignored" do
    note = "1. Three points\n2. Over 8 days and 5 questions, see [the case](https://www.cyrillepierre.com/realisations#n01), " \
           "N°13, a 30-minute call, 1,200 words. ###VERSION_FINALE###"

    assert_empty unsourced(note)
  end

  test "a formula supports a figure only if it reads, uses sourced operands and lands on it" do
    audit = FigureAudit.new(SOURCE)
    point = audit.unsourced("One point of revenue is €307k.").first
    growth = audit.unsourced("Revenue grew 14.5% since 2021.").first

    assert audit.supports?(point, "30,7 M€ × 1 %")
    assert audit.supports?(point, "30 729 278 € / 100")
    assert audit.supports?(growth, "(30,7 M€ − 26,8 M€) / 26,8 M€")
    assert audit.supports?(audit.unsourced("The gap is €3.9m.").first, "-26,8 M€ + 30,7 M€")
    assert_not audit.supports?(point, "30,7 M€ × 2 %")
    assert_not audit.supports?(point, "4,9 M€ × 6 %"), "un opérande inventé ne soutient rien"
    assert_not audit.supports?(point, "n'importe quoi")
    assert_not audit.supports?(point, "30,7 M€ × (1 %")
  end

  test "same_figure? recognises the figure a journal line talks about, whatever its spelling" do
    audit = FigureAudit.new(SOURCE)
    point = audit.unsourced("One point of revenue is €307k.").first

    assert audit.same_figure?(point, "307 K€ = 30,7 M€ × 1 %")
    assert_not audit.same_figure?(point, "950 K€ = 30,7 M€ × 3 %")
  end
end
