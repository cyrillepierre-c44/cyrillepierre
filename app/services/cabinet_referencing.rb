# Les cabinets de management de transition sont des clients à se faire référencer (idée de
# Cyrille du 22/09/2026, détail dans docs/cabinets-management-de-transition.md). Ce service pose
# une fiche par cabinet dans le pipeline, une par jour ouvré, pour qu'elles remontent le matin
# comme n'importe quelle relance. Idempotent : une fiche déjà présente (même entreprise, source
# « cabinet ») n'est pas recréée. Lancé par `rails prospects:cabinets`.
class CabinetReferencing
  CABINETS = [
    { company: "Aptimen Managers — cabinet de management de transition, Lyon",
      url: "https://aptimen-managers.com/espace-managers/",
      notes: "Bureau : 19 rue Maurice Bouchor, 69007 Lyon, 04 78 37 02 81 (Stéphane Martinod, Marine Dumont, " \
             "Jean-Marc Bury). Cabinet lyonnais depuis 2009, industrie et agroalimentaire dans ses secteurs." },
    { company: "KeyWe — cabinet de management de transition, Lyon",
      url: "https://keywe-transition.com/candidature-et-actualisation-cv-managers-de-transition/",
      notes: "Bureau : 72 rue Tronchet, 69006 Lyon, 06 18 71 76 60 (Marjolaine Briquet, directrice du " \
             "développement). Portail de candidature tzportal ; industrie et supply chain dans ses secteurs." },
    { company: "Wayden — cabinet de management de transition (bureau de Lyon)",
      url: "https://managers.wayden.fr",
      notes: "100 % transition, industrie parmi ses trois métiers. 15 % des candidats retenus ; entretien de " \
             "qualification par un associé si le profil colle. Adresse du bureau de Lyon non publiée." },
    { company: "Delville Management — cabinet de management de transition (bureau de Lyon)",
      url: "https://monespacemanager.delville-management.com",
      notes: "Cinq étapes : CV et pitch, entretien de qualification, questionnaires de personnalité " \
             "(facultatifs), prise de références systématique, entretien avec un directeur de mission." },
    { company: "Valtus — cabinet de management de transition (Paris)",
      url: "https://espace.valtus.fr/?lang=fr",
      notes: "Leader français. CV de deux à trois pages ; entretien exploratoire si le profil répond à des " \
             "besoins récurrents ; références et langues vérifiées. Pas de bureau lyonnais mentionné." },
    { company: "X-PM (réseau Alixio) — cabinet de management de transition (Paris)",
      url: "https://portails.management-transition-xpm.com/candidateportal",
      notes: "Portail candidat. Positionné sur les groupes avec filiales à l'étranger." },
    { company: "MCG Managers — cabinet de management de transition",
      url: "https://www.mcgmanagers.com/candidats-managers/",
      notes: "Fondé en 1990, page industrie dédiée, sélection annoncée comme exigeante. Bureau lyonnais à " \
             "vérifier (site inaccessible le 24/09/2026)." },
    { company: "Robert Walters Management de Transition — bureau de Lyon",
      url: "https://www.robertwalters.fr/management-de-transition/contactez-nous/france/lyon.html",
      notes: "Certifié Bureau Veritas. Page de Lyon non lisible par un robot le 24/09/2026 : passer par le " \
             "bureau de Lyon directement." }
  ].freeze

  SUMMARY = "Cabinet à se faire référencer : il facture le client final et paie le manager. " \
            "Voir docs/cabinets-management-de-transition.md (CV missions, pitch, références, tarif).".freeze

  # Crée les fiches manquantes, rattachées à `user`, datées à partir du jour ouvré qui suit `from`.
  # Rend le nombre de fiches créées.
  def self.create_missing!(user:, from: Date.current)
    day = from
    CABINETS.count do |cabinet|
      day = next_working_day(day)
      next false if Prospect.source_cabinet.exists?(company: cabinet[:company])

      Prospect.create!(
        user: user, name: Prospect::PLACEHOLDER_NAME, company: cabinet[:company],
        sector: "Management de transition", source: :cabinet, status: :a_contacter,
        summary: SUMMARY, notes: cabinet[:notes],
        next_action: "Se faire référencer : #{cabinet[:url]} — puis appeler le bureau de Lyon s'il existe",
        next_action_on: day
      )
      true
    end
  end

  def self.next_working_day(day)
    day = day.next_day
    day = day.next_day while day.saturday? || day.sunday?
    day
  end
end
