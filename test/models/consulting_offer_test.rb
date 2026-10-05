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
  end

  test "the sixteen levers are numbered for the prompt" do
    assert_equal 16, ConsultingOffer::LEVERS.size
    assert ConsultingOffer.levers_prompt.start_with?("1. Productivité de la main-d'œuvre directe — charges de personnel")
  end
end
