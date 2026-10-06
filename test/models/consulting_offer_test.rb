require "test_helper"

class ConsultingOfferTest < ActiveSupport::TestCase
  test "each schedule adds up to the whole price" do
    ConsultingOffer::DIAGNOSTICS.each_value do |diagnostic|
      assert_equal 100, diagnostic[:schedule].sum(&:first), diagnostic[:name]
      assert_equal diagnostic[:price], diagnostic[:days] * ConsultingOffer::DAILY_RATE, diagnostic[:name]
    end
  end

  # Les montants du document « Offre de conseil » validés par Cyrille le 05/10/2026.
  test "the conditions state the agreed prices, instalments and bridge" do
    text = ConsultingOffer.conditions_markdown

    assert_includes text, "Diagnostic express : 8 000 € HT, 8 jours"
    assert_includes text, "50 % à la commande (4 000 € HT), 50 % à la remise du diagnostic (4 000 € HT)"
    assert_includes text, "Diagnostic complet : 30 000 € HT, 30 jours"
    assert_includes text, "30 % à la commande (9 000 € HT), 40 % à la remise de l'analyse financière (12 000 € HT)"
    assert_includes text, "dans les 3 mois qui suivent la remise de l'express, pour le même site"
    assert_includes text, "1 000 € HT par jour"
    assert_includes text, "30 jours date de facture"
    assert_includes text, "des estimations"
    assert_no_match(/quick win/i, text)
    # Décision du 06/10/2026 : l'express ne couvre jamais le site entier, sinon il sert de prix d'appel.
    assert_includes text, "un seul atelier ou une seule ligne de production, jamais le site entier"
  end

  test "the sixteen levers are numbered for the prompt" do
    assert_equal 16, ConsultingOffer::LEVERS.size
    assert ConsultingOffer.levers_prompt.start_with?("1. Productivité de la main-d'œuvre directe — charges de personnel")
  end

  test "the eight wastes are named, and every lever points to at least one of them" do
    assert_equal %w[Transport Inventaire Mouvements Attente Surproduction Sur-traitement Défauts Compétences],
                 ConsultingOffer::WASTES.values.map(&:first)
    ConsultingOffer::LEVERS.each do |name, _line, wastes|
      assert wastes.any?, name
      assert (wastes - ConsultingOffer::WASTES.keys).empty?, name
    end
    assert_includes ConsultingOffer.wastes_prompt, "le surdosage en est un"
  end

  test "a recommended format shows alone, the bridge only after an express" do
    express = ConsultingOffer.conditions_markdown(:express)
    complet = ConsultingOffer.conditions_markdown(:complet)

    assert_includes express, "8 000 € HT"
    assert_not_includes express, "30 000 €"
    assert_includes express, "le prix de l'express en est déduit"
    assert_includes complet, "30 000 € HT"
    assert_not_includes complet, "8 000 €"
    assert_not_includes complet, "le prix de l'express en est déduit"
  end
end

