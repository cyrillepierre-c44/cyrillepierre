require "test_helper"

class ConsultingOfferTest < ActiveSupport::TestCase
  # Barème validé par Cyrille le 17/11/2026 : 1 400 € HT jusqu'à 10 jours, 1 250 € de 11 à 29, 1 100 € à partir
  # de 30 ou en temps partagé. Un forfait peut s'arrondir un peu sous le taux de sa tranche, jamais au-dessus — un
  # prix d'entrée sous le taux se défend, un taux qu'on voudra monter plus tard non.
  test "each schedule adds up to the whole price, and no format exceeds the rate of its volume" do
    ConsultingOffer::DIAGNOSTICS.each_value do |diagnostic|
      assert_equal 100, diagnostic[:schedule].sum(&:first), diagnostic[:name]
      rate = ConsultingOffer.rate_for(diagnostic[:days])
      implied = diagnostic[:price].fdiv(diagnostic[:days])
      assert implied <= rate, diagnostic[:name]
      assert implied >= rate * 0.95, diagnostic[:name]
    end
    assert_equal [1_400, 1_400, 1_250, 1_250, 1_100, 1_100],
                 [1, 10, 11, 29, 30, 120].map { |days| ConsultingOffer.rate_for(days) }
    assert_equal ConsultingOffer::LONG_RATE, ConsultingOffer::RELAY_DAILY_RATE
  end

  # Les montants validés par Cyrille le 21/10/2026 (reprise de l'offre à l'aune de l'IA).
  test "the conditions state the agreed prices, instalments, rhythms and bridges" do
    text = ConsultingOffer.conditions_markdown

    assert_includes text, "Atelier de direction « assis / debout » : 7 000 € HT, 5 jours"
    assert_includes text, "50 % à la commande (3 500 € HT), 50 % à la restitution (3 500 € HT)"
    assert_includes text, "Diagnostic express : 11 000 € HT, 8 jours"
    assert_includes text, "50 % à la commande (5 500 € HT), 50 % à la remise du diagnostic (5 500 € HT)"
    assert_includes text, "Diagnostic complet : 33 000 € HT, 30 jours"
    # L'analyse financière n'est plus un jalon payé : l'IA la produit, le terrain non (21/10/2026).
    assert_includes text, "30 % à la commande (9 900 € HT), 40 % à la remise de l'arbre des pertes (13 200 € HT)"
    assert_not_includes text, "remise de l'analyse financière"
    assert_includes text, "Chaque étape se déduit de la suivante"
    # Les trois rythmes d'exécution, avec leur prix.
    assert_includes text, "Chantiers groupés : une équipe pluridisciplinaire détachée"
    assert_includes text, "1 400 € HT par jour sur site jusqu'à 10 jours commandés, 1 250 € HT de 11 à 29 jours, " \
                          "1 100 € HT à partir de 30 jours"
    assert_includes text, "Un jour par semaine : six à douze mois"
    assert_includes text, "4 700 € HT par mois"
    assert_includes text, "Relais de direction : un poste de direction tenu sur site à la journée"
    assert_includes text, "trois à quatre mois, avec une lettre de mission et une passation écrite — 1 100 € HT par jour"
    # L'outil de suivi n'est plus un logiciel vendu par abonnement.
    assert_includes text, "je le conçois avec vos équipes, qui le construisent et le gardent"
    assert_includes text, "Aucun abonnement"
    assert_not_includes text, "abonnement mensuel"
    # Clause de moyens côté client (28/10/2026) : un livrable, jamais un résultat, et les journées annulées tard
    # sont dues — le forfait par chantier n'est plus « avec son objectif mesuré ».
    assert_includes text, "Ce que je demande de votre côté."
    assert_includes text, "Une journée que vous annulez à moins de deux jours ouvrés est due en entier"
    assert_includes text, "au forfait par chantier, sur des jours planifiés avec les personnes nommées"
    assert_not_includes text, "objectif mesuré"
    # Obligation de moyens (17/11/2026) : primes, organisation et dialogue social restent au client.
    assert_includes text, "Je m'engage sur les moyens, pas sur un résultat"
    assert_includes text, "consultation des représentants du personnel"
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

  test "a recommended format shows alone, with the bridge that follows it" do
    atelier = ConsultingOffer.conditions_markdown(:atelier)
    express = ConsultingOffer.conditions_markdown(:express)
    complet = ConsultingOffer.conditions_markdown(:complet)

    assert_includes atelier, "7 000 € HT"
    assert_not_includes atelier, "11 000 €"
    assert_not_includes atelier, "33 000 €"
    assert_includes atelier, "le prix de l'atelier en est déduit"
    assert_includes express, "11 000 € HT"
    assert_not_includes express, "7 000 €"
    assert_not_includes express, "33 000 €"
    assert_includes express, "le prix de l'express en est déduit"
    assert_includes complet, "33 000 € HT"
    assert_not_includes complet, "11 000 €"
    assert_not_includes complet, "7 000 €"
    assert_not_includes complet, "déduit"
  end
end
