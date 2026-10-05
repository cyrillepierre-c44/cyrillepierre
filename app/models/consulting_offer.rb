# L'offre de conseil, telle que Cyrille l'a arrêtée le 05/10/2026 (document « Offre de conseil — des
# comptes au terrain ») : un diagnostic payé dès la commande, puis un plan d'amélioration en tiroirs,
# puis l'exécution. Les prix et l'échéancier vivent ici et nulle part ailleurs : la proposition
# commerciale du Studio ne les confie jamais au modèle, Ruby les écrit lui-même sous le texte rédigé
# (ContentGenerator#append_conditions). Un modèle qui recopie un prix peut le recopier faux.
module ConsultingOffer
  DAILY_RATE = 1_000

  # Le complet se paie en trois fois ; le « mi-parcours » est un livrable, pas une date qui glisse.
  DIAGNOSTICS = {
    express: {
      name: "Diagnostic express",
      days: 8,
      price: 8_000,
      scope: "les comptes des trois derniers exercices, une visite approfondie du site, un arbre des pertes " \
             "simplifié où chaque perte est rangée dans l'un des huit gaspillages, et trois gisements " \
             "chiffrés en euros",
      schedule: [[50, "à la commande"], [50, "à la remise du diagnostic"]]
    },
    complet: {
      name: "Diagnostic complet",
      days: 30,
      price: 30_000,
      scope: "trois à cinq exercices, une immersion sur le site (observations au poste, entretiens de " \
             "l'opérateur au directeur), la revue des seize leviers, un arbre des pertes complet où chaque perte est " \
             "rangée dans l'un des huit gaspillages, et les " \
             "gisements classés par euros récupérables, avec leur investissement et leur temps interne",
      schedule: [[30, "à la commande"], [40, "à la remise de l'analyse financière"],
                 [30, "à la remise du diagnostic"]]
    }
  }.freeze

  BRIDGE_MONTHS = 3
  PAYMENT_DAYS = 30

  # Les huit gaspillages (TIMWOODS), dans les mots de Cyrille (05/10/2026). Une perte n'est presque jamais
  # « de la matière tombée par terre » : une dérive des achats consommés, c'est aussi de la surproduction
  # jetée, du surdosage, de la non-qualité. Le diagnostic classe les pertes selon ces huit familles.
  WASTES = {
    transport: ["Transport", "déplacement inutile de matériel ou de produits"],
    inventory: ["Inventaire", "excès de stock ou de matières premières qui encombrent l'espace"],
    motion: ["Mouvements", "gestes superflus ou déplacements inutiles des employés"],
    waiting: ["Attente", "temps perdu à attendre des pièces, des informations ou une machine"],
    overproduction: ["Surproduction", "produire plus ou plus tôt que la demande réelle"],
    overprocessing: ["Sur-traitement", "faire plus de travail, d'analyses ou de matière que nécessaire pour " \
                                       "le client — le surdosage en est un"],
    defects: ["Défauts", "produits non conformes nécessitant des retouches ou un rebut"],
    skills: ["Compétences", "sous-utilisation du potentiel, de l'expérience et des talents des équipes"]
  }.freeze

  # Les tiroirs de l'étape 2 : chaque levier part d'une ligne des comptes, c'est ce qui permet de
  # relier un chantier d'atelier au résultat que lit le dirigeant, et nomme les gaspillages qui
  # nourrissent typiquement cette ligne — ceux que le diagnostic ira chercher.
  LEVERS = [
    ["Productivité de la main-d'œuvre directe", "charges de personnel", %i[waiting motion transport skills]],
    ["Structure et main-d'œuvre indirecte", "charges de personnel, frais généraux", %i[overprocessing waiting skills]],
    ["Performance des équipements (TRS)", "coût de revient, investissements évités",
     %i[waiting defects overproduction]],
    ["Maintenance", "entretien et réparations, stock de pièces", %i[waiting inventory skills]],
    ["Non-qualité", "coût de revient, avoirs clients", %i[defects overprocessing]],
    ["Rendement matière", "achats consommés", %i[overprocessing overproduction defects inventory]],
    ["Achats", "achats consommés, sous-traitance", %i[inventory overprocessing]],
    ["BFR : stocks", "stocks au bilan", %i[inventory overproduction]],
    ["BFR : délais clients et fournisseurs", "créances et dettes au bilan", %i[waiting defects]],
    ["Supply chain et logistique", "transports, entreposage", %i[transport inventory waiting]],
    ["Énergie et utilités", "énergie, eau", %i[overproduction waiting overprocessing]],
    ["Déchets et environnement", "charges externes", %i[defects overproduction]],
    ["Sécurité et absentéisme", "cotisations AT/MP, remplacements", %i[motion skills]],
    ["Investissements", "investissements, amortissements", %i[overproduction overprocessing]],
    ["Organisation et management", "transversal", %i[skills waiting]],
    ["Pilotage et données", "transversal", %i[overprocessing waiting]]
  ].freeze

  def self.wastes_prompt
    WASTES.values.map { |label, definition| "- #{label} : #{definition}" }.join("\n")
  end

  def self.waste_labels(keys)
    keys.map { |key| WASTES.fetch(key).first.downcase }.join(", ")
  end

  def self.levers_prompt
    LEVERS.each_with_index.map do |(name, line, wastes), i|
      "#{i + 1}. #{name} — #{line} — gaspillages à chercher : #{waste_labels(wastes)}"
    end.join("\n")
  end

  def self.euros(amount)
    "#{amount.to_s.reverse.scan(/\d{1,3}/).join(' ').reverse} €"
  end

  def self.schedule_line(diagnostic)
    diagnostic[:schedule].map do |share, moment|
      "#{share} % #{moment} (#{euros(diagnostic[:price] * share / 100)} HT)"
    end.join(", ")
  end

  # Écrit tel quel sous la proposition, après la relecture orthographique : rien ici ne passe par
  # un modèle.
  def self.conditions_markdown
    express, complet = DIAGNOSTICS.values_at(:express, :complet)
    <<~MARKDOWN.strip
      ## Conditions

      **Étape 1 — le diagnostic, au forfait, payé dès la commande**

      - #{express[:name]} : #{euros(express[:price])} HT, #{express[:days]} jours de travail — #{express[:scope]}. Échéancier : #{schedule_line(express)}.
      - #{complet[:name]} : #{euros(complet[:price])} HT, #{complet[:days]} jours de travail — #{complet[:scope]}. Échéancier : #{schedule_line(complet)}.
      - Si le diagnostic complet est commandé dans les #{BRIDGE_MONTHS} mois qui suivent la remise de l'express, pour le même site, le prix de l'express en est déduit.

      **Étape 2 — le plan d'amélioration** : chaque module retenu est chiffré au forfait à l'issue du diagnostic, avec son gain estimé, son investissement éventuel et le temps à libérer chez vous.

      **Étape 3 — l'exécution** : #{euros(DAILY_RATE)} HT par jour sur site, ou au forfait par chantier, facturée au mois.

      **Option — l'outil de suivi** : mise en place au forfait puis abonnement mensuel, sur devis.

      Les travaux démarrent à l'encaissement de l'acompte. Factures payables à #{PAYMENT_DAYS} jours date de facture. Missions sur site depuis Lyon, à la journée : frais kilométriques seulement au-delà du rayon convenu, aucun frais d'hébergement. Les gains présentés dans le diagnostic et le plan sont des estimations : leur obtention dépend des décisions prises et du temps libéré par vos équipes.
    MARKDOWN
  end
end
