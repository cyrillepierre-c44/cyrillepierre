require "test_helper"

# Les renseignements sont composés en Ruby à partir des réponses d'API : chaque ligne du texte
# se vérifie contre la réponse simulée, et rien n'y apparaît qui n'en vienne.
class ProspectEnricherTest < ActiveSupport::TestCase
  ANNUAIRE = {
    results: [{
      nom_complet: "MAPEI FRANCE", siren: "323469106", categorie_entreprise: "ETI", date_creation: "1981-10-26",
      activite_principale: "20.52Z", tranche_effectif_salarie: "32", nombre_etablissements_ouverts: 8,
      siege: { adresse: "ZI DU TERROIR AVENUE LEON JOUHAUX 31140 SAINT-ALBAN" },
      matching_etablissements: [{ libelle_commune: "SAINT-ALBAN" }, { libelle_commune: "SAINT-VULBAS" }],
      finances: { "2024" => { ca: 120_000_000, resultat_net: 1_000_000 }, "2025" => { ca: 125_053_534, resultat_net: -3_737_043 } },
      dirigeants: [{ nom: "JEAUNEAU", prenoms: "CHRISTOPHE", qualite: "Directeur Général" },
                   { qualite: "Commissaire aux comptes titulaire" },
                   { nom: "SQUINZI", prenoms: "MARCO", qualite: "Président du conseil d’administration" }]
    }]
  }.freeze

  setup do
    user = User.create!(email: "enrich-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @prospect = Prospect.create!(user: user, name: "Décideur à identifier", company: "MAPEI France — usine de Saint-Vulbas (01)")
    travel_to Time.zone.local(2026, 9, 22, 12, 0)
  end

  teardown { travel_back }

  def stub_sources(annuaire: ANNUAIRE, bodacc: nil, rss: nil)
    stub_request(:get, %r{recherche-entreprises\.api\.gouv\.fr/search\?per_page=3&q=MAPEI(%20|\+)France})
      .to_return(status: 200, body: annuaire.to_json, headers: { "Content-Type" => "application/json" })
    bodacc ||= { total_count: 2, results: [{ dateparution: "2026-01-15", familleavis_lib: "Dépôts des comptes" },
                                           { dateparution: "2025-11-03", familleavis_lib: "Modifications diverses" }] }
    stub_request(:get, %r{bodacc-datadila\.opendatasoft\.com/.*323469106.*2025-09-22})
      .to_return(status: 200, body: bodacc.to_json)
    rss ||= <<~XML
      <rss><channel>
        <item><title>Mapei se développe entre croissance externe et investissements - Le Moniteur</title>
          <link>https://example.com/a</link><pubDate>Fri, 01 Aug 2026 07:00:00 GMT</pubDate></item>
        <item><title>Vieille nouvelle - Le Progrès</title><link>https://example.com/b</link>
          <pubDate>Mon, 03 Feb 2014 08:00:00 GMT</pubDate></item>
      </channel></rss>
    XML
    stub_request(:get, %r{news\.google\.com/rss/search\?.*q=%22MAPEI(%20|\+)France%22}).to_return(status: 200, body: rss)
  end

  test "composes identity, last accounts, legal representatives, BODACC notices and recent press from the APIs" do
    stub_sources

    result = ProspectEnricher.call(@prospect)

    assert_equal "323469106", result.siren
    text = result.text
    assert_includes text, "- MAPEI FRANCE · SIREN 323469106 · ETI · créée le 26/10/1981"
    assert_includes text, "- Siège : ZI DU TERROIR AVENUE LEON JOUHAUX 31140 SAINT-ALBAN"
    assert_includes text, "- Effectif (tranche) : 250 à 499 salariés"
    assert_includes text, "- Établissements (8 ouverts) : SAINT-ALBAN, SAINT-VULBAS"
    assert_includes text, "- Dernier exercice publié (2025) : chiffre d'affaires 125,1 M€, résultat net -3,7 M€, (-3.0 % du CA) — un seul exercice"
    assert_includes text, "Représentants légaux (pas le directeur du site) : CHRISTOPHE JEAUNEAU (Directeur Général) · MARCO SQUINZI"
    assert_not_includes text, "Commissaire"
    assert_includes text, "BODACC (12 derniers mois, 2 avis) :\n- 15/01/2026 : Dépôts des comptes\n- 03/11/2025 : Modifications diverses"
    assert_includes text, "PRESSE (12 derniers mois, titres seulement — lire l'article avant de citer) :\n- 01/08/2026 : Mapei se développe"
    assert_not_includes text, "Vieille nouvelle"
  end

  test "says so when the directory knows nothing, and keeps going with the press" do
    stub_sources(annuaire: { results: [] })

    text = ProspectEnricher.call(@prospect).text

    assert_includes text, "aucune société trouvée pour « MAPEI France »"
    assert_not_includes text, "BODACC"
    assert_includes text, "PRESSE"
  end

  test "a failing secondary source is reported in place, not raised" do
    stub_sources
    stub_request(:get, %r{bodacc-datadila}).to_return(status: 500, body: "")
    stub_request(:get, %r{news\.google\.com}).to_timeout

    text = ProspectEnricher.call(@prospect).text

    assert_includes text, "BODACC : lecture impossible (RuntimeError)."
    assert_includes text, "PRESSE : lecture impossible"
    assert_includes text, "SIREN 323469106"
  end

  test "a known SIREN is searched instead of the name, and an empty company yields no identity" do
    @prospect.update!(siren: "323469106")
    stub_request(:get, %r{recherche-entreprises\.api\.gouv\.fr/search\?per_page=3&q=323469106}).to_return(status: 200, body: ANNUAIRE.to_json)
    stub_request(:get, %r{bodacc-datadila}).to_return(status: 200, body: { total_count: 0, results: [] }.to_json)
    stub_request(:get, %r{news\.google\.com}).to_return(status: 200, body: "<rss><channel></channel></rss>")

    text = ProspectEnricher.call(@prospect).text

    assert_includes text, "BODACC (12 derniers mois) : aucun avis."
    assert_includes text, "rien trouvé sur « MAPEI France »"

    @prospect.update!(siren: nil, company: nil)
    assert_includes ProspectEnricher.call(@prospect).text, "aucune société trouvée"
  end

  test "small amounts, an unknown creation date and an unreadable press date" do
    company = ANNUAIRE[:results].first.merge(date_creation: nil, finances: { "2025" => { ca: 450_000, resultat_net: 800 } })
    rss = "<rss><channel><item><title>Sans date</title><link>https://example.com/c</link><pubDate>n/a</pubDate></item>" \
          "</channel></rss>"
    stub_sources(annuaire: { results: [company] }, rss: rss)

    text = ProspectEnricher.call(@prospect).text

    assert_includes text, "créée le date inconnue"
    assert_includes text, "chiffre d'affaires 450 K€, résultat net 800 €"
    assert_includes text, "rien trouvé sur « MAPEI France »"
  end

  test "money and figures without accounts" do
    company = ANNUAIRE[:results].first.merge(finances: {}, dirigeants: [], matching_etablissements: [], tranche_effectif_salarie: "99")
    stub_sources(annuaire: { results: [company] })

    text = ProspectEnricher.call(@prospect).text

    assert_not_includes text, "Dernier exercice"
    assert_not_includes text, "Représentants"
    assert_not_includes text, "Effectif"
  end
end
