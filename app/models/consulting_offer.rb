# L'offre de conseil, telle que Cyrille l'a arrêtée le 05/10/2026 (document « Offre de conseil — des
# comptes au terrain ») et reprise le 21/10/2026 à l'aune de l'IA : ce qui se fait au bureau, loin du
# terrain (analyse financière, rédaction, exploitation de données), le client le fera avec une IA et ne se
# vend plus comme valeur ; ce qui se vend se fait debout dans l'atelier ou se décide en face à face. D'où
# trois portes d'entrée payées dès la commande (atelier de direction, diagnostic express, diagnostic
# complet), un plan d'amélioration en tiroirs, puis l'exécution en trois rythmes. Les prix et l'échéancier
# vivent ici et nulle part ailleurs : la proposition commerciale du Studio ne les confie jamais au modèle,
# Ruby les écrit lui-même sous le texte rédigé (ContentGenerator#append_conditions). Un modèle qui recopie
# un prix peut le recopier faux.
# Module de données (prix, échéanciers, gaspillages, seize leviers) : le découper en deux ferait vivre
# l'offre à deux endroits, ce que ce fichier existe précisément pour éviter.
module ConsultingOffer # rubocop:disable Metrics/ModuleLength
  # Modèle économique du 21/10/2026 : 100 jours payés par an pour 120 000 € HT au moins, le reste du temps
  # en commercial non rémunéré. Les forfaits d'entrée s'arrondissent un peu sous ce taux, jamais au-dessus.
  DAILY_RATE = 1_400
  # Le relais de direction est moins cher : des mois pleins suppriment le temps commercial, et c'est le prix
  # du marché direct de la transition locale. Règle interne, qui n'est pas une condition client : un relais
  # par an au plus, et pas au-delà de RELAY_MAX_MONTHS — un an de relais est un CDD, le pipeline s'éteint.
  RELAY_DAILY_RATE = 1_200
  RELAY_MAX_MONTHS = 4
  # « Un jour par semaine » se facture au mois : 4,3 jours par mois en moyenne, au taux plein.
  WEEKLY_MONTHLY_FEE = 6_000

  # Les trois portes d'entrée. Le complet se paie en trois fois ; le « mi-parcours » est un livrable, pas une
  # date qui glisse — et depuis le 21/10/2026 ce livrable est l'arbre des pertes, plus l'analyse financière :
  # celle-ci se produit en quelques heures avec l'outil de Cyrille et se remet en ouverture, elle ne se
  # facture plus comme un jalon.
  DIAGNOSTICS = {
    # Porte d'entrée née de la réflexion du 21/10/2026 (HEC Lift : les dirigeants, peu exposés à l'IA,
    # doivent réorganiser leurs n-1 qui le sont). Cinq jours, pas un : méthode que Cyrille développera
    # lui-même, avec une application dédiée. Un montant qu'un directeur d'usine signe dans sa délégation.
    atelier: {
      name: "Atelier de direction « assis / debout »",
      days: 5,
      price: 7_000,
      scope: "cinq jours avec le dirigeant et son comité : les comptes et les entretiens, deux jours entre " \
             "l'atelier et les fonctions support, puis la construction et la restitution ; le livrable est la " \
             "carte des tâches du site que l'IA fera dans les douze mois (contrôle de gestion, méthodes, " \
             "ordonnancement, qualité documentaire, administration), la carte des pertes de l'atelier que " \
             "personne ne traite, et le plan de redéploiement des personnes avec son calendrier social",
      schedule: [[50, "à la commande"], [50, "à la restitution"]]
    },
    express: {
      name: "Diagnostic express",
      days: 8,
      price: 11_000,
      # Un atelier ou une ligne, jamais le site entier (décision du 06/10/2026) : sinon un grand groupe
      # prendrait l'express comme prix d'appel pour un diagnostic de site.
      scope: "un seul atelier ou une seule ligne de production, jamais le site entier : les comptes des trois " \
             "derniers exercices lus en ouverture, une visite approfondie de ce périmètre, un arbre des pertes " \
             "simplifié où chaque perte est rangée dans l'un des huit gaspillages, y compris celles qu'aucun " \
             "compteur ne mesure, et trois gisements chiffrés en euros",
      schedule: [[50, "à la commande"], [50, "à la remise du diagnostic"]]
    },
    complet: {
      name: "Diagnostic complet",
      days: 30,
      price: 40_000,
      scope: "le site entier : l'analyse financière de trois à cinq exercices remise en ouverture, une immersion " \
             "sur le site (observations au poste, entretiens de l'opérateur au directeur), la revue des seize " \
             "leviers, un arbre des pertes complet où chaque perte est rangée dans l'un des huit gaspillages, " \
             "remis à mi-parcours, et les gisements classés par euros récupérables, avec leur investissement " \
             "et leur temps interne",
      schedule: [[30, "à la commande"], [40, "à la remise de l'arbre des pertes"],
                 [30, "à la remise du diagnostic"]]
    }
  }.freeze

  # L'exécution en trois rythmes (21/10/2026) : le client choisit selon le temps qu'il peut libérer, qui est
  # chiffré dans le plan. Les prix s'écrivent ici en toutes lettres pour les conditions.
  EXECUTION = [
    ["Chantiers groupés", "une équipe pluridisciplinaire détachée, plusieurs chantiers menés de front sur " \
                          "quatre à huit semaines, un animateur interne formé pour la suite",
     "%s HT par jour sur site, ou au forfait par chantier, sur des jours planifiés avec les personnes nommées"],
    ["Un jour par semaine", "six à douze mois, l'animation de la performance et un chantier à la fois avec les " \
                            "personnes disponibles, un journal de bord d'une page chaque semaine",
     "%s HT par mois"],
    ["Relais de direction", "un poste de direction tenu sur site à la journée, trois à quatre mois, avec une " \
                            "lettre de mission et une passation écrite",
     "%s HT par jour"]
  ].freeze

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
  # Clause de moyens côté client (28/10/2026, demande de Cyrille : chez EFESO, une fois sur trois, les
  # ressources d'un chantier étaient annulées la veille et le forfait absorbait). Le forfait ne couvre que ce que
  # Cyrille produit seul (arbre des pertes, carte assis / debout) : un livrable, jamais un résultat ; les chantiers
  # dépendent des équipes libérées, donc son paiement ne dépend jamais de l'effort du client — ses livrables
  # déclenchent ses factures, les journées annulées tard déclenchent les leurs. Barème des cabinets (deux jours
  # ouvrés : due en entier ; cinq : à moitié), qu'un DAF reconnaît sans le discuter.
  CLIENT_COMMITMENTS = <<~TXT.strip
    **Ce que je demande de votre côté.** Pour la porte d'entrée : un référent nommé, l'accès à l'atelier à toutes les équipes, y compris de nuit et de week-end, les données demandées sous cinq jours ouvrés, et deux heures par semaine avec vous. Un accès qui manque décale la remise d'autant ; les jours déjà passés restent dus. Pour l'exécution : les membres de chaque chantier sont nommés dans la commande, et leurs demi-journées bloquées quatre semaines à l'avance. Une journée que vous annulez à moins de deux jours ouvrés est due en entier, entre deux et cinq jours ouvrés à moitié ; au-delà, elle se reporte sans frais. Un chantier au forfait est un nombre de jours planifiés avec ces personnes : les jours qu'il faut ajouter parce qu'elles ont manqué se facturent au jour.
  TXT

  # Un seul format affiché quand la proposition en recommande un (parade A du 06/10/2026 : montrés côte à
  # côte, l'express servait de prix d'appel) ; les trois, par sécurité, quand le format n'est pas connu.
  def self.conditions_markdown(format = nil)
    <<~MARKDOWN.strip
      ## Conditions

      **Étape 1 — la porte d'entrée, au forfait, payée dès la commande**

      #{diagnostic_lines(format)}

      **Étape 2 — le plan d'amélioration** : chaque module retenu est chiffré au forfait à l'issue du diagnostic, avec son gain estimé, son investissement éventuel et le temps à libérer chez vous.

      **Étape 3 — l'exécution, au rythme que vos équipes peuvent tenir** :

      #{execution_lines}

      **L'outil de suivi des pertes** : je le conçois avec vos équipes, qui le construisent et le gardent ; accompagnement au forfait, sur devis. Aucun abonnement.

      #{CLIENT_COMMITMENTS}

      Les travaux démarrent à l'encaissement de l'acompte. Factures payables à #{PAYMENT_DAYS} jours date de facture. Missions sur site depuis Lyon, à la journée : frais kilométriques seulement au-delà du rayon convenu, aucun frais d'hébergement. Les gains présentés dans le diagnostic et le plan sont des estimations : leur obtention dépend des décisions prises et du temps libéré par vos équipes.
    MARKDOWN
  end

  def self.execution_lines
    prices = [euros(DAILY_RATE), euros(WEEKLY_MONTHLY_FEE), euros(RELAY_DAILY_RATE)]
    EXECUTION.zip(prices).map do |(name, shape, price), amount|
      "- #{name} : #{shape} — #{price % amount}."
    end.join("\n")
  end

  # La porte d'entrée précédente se déduit de la suivante, commandée dans les BRIDGE_MONTHS mois pour le
  # même site : l'atelier d'un diagnostic, l'express du complet. Rien ne se déduit après un complet.
  def self.diagnostic_lines(format)
    keys = DIAGNOSTICS.key?(format) ? [format] : DIAGNOSTICS.keys
    lines = keys.map do |key|
      diagnostic = DIAGNOSTICS.fetch(key)
      "- #{diagnostic[:name]} : #{euros(diagnostic[:price])} HT, #{diagnostic[:days]} jours de travail — " \
        "#{diagnostic[:scope]}. Échéancier : #{schedule_line(diagnostic)}."
    end
    lines << bridge_line(format) unless format == :complet
    lines.join("\n")
  end

  def self.bridge_line(format)
    case format
    when :atelier
      "- Si un diagnostic, express ou complet, est commandé dans les #{BRIDGE_MONTHS} mois qui suivent la " \
      "restitution de l'atelier, pour le même site, le prix de l'atelier en est déduit."
    when :express
      "- Si le diagnostic du site entier est commandé dans les #{BRIDGE_MONTHS} mois qui suivent la remise " \
      "de l'express, pour le même site, le prix de l'express en est déduit."
    else
      "- Chaque étape se déduit de la suivante : le prix de l'atelier d'un diagnostic commandé dans les " \
      "#{BRIDGE_MONTHS} mois qui suivent sa restitution, le prix de l'express du diagnostic du site entier " \
      "commandé dans les #{BRIDGE_MONTHS} mois qui suivent sa remise, pour le même site."
    end
  end
end
