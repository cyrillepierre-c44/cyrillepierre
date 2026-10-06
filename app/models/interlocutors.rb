# Pourquoi écrire à CE destinataire (le discours, chantier 5 du 06/10/2026) : chacun porte une ligne des
# comptes, et c'est elle qui justifie qu'on s'adresse à lui plutôt qu'à un autre. Un DAF lit le BFR, un
# directeur d'usine le coût de revient et les heures. Les leviers renvoient à ConsultingOffer::LEVERS.
module Interlocutors
  LIST = [
    ["Dirigeant (président, directeur général, gérant)", "la marge, l'EBE et la trésorerie",
     "l'ensemble des leviers, résumés en euros"],
    ["Directeur financier (DAF)", "le BFR, la trésorerie et la marge brute",
     "stocks, délais clients et fournisseurs, achats"],
    ["Directeur d'usine, de site, industriel ou des opérations", "le coût de revient, les heures et le TRS",
     "main-d'œuvre directe, équipements, non-qualité, rendement matière, énergie"],
    ["Directeur des ressources humaines", "la masse salariale, l'intérim et l'absentéisme",
     "main-d'œuvre directe et indirecte, sécurité et absentéisme"],
    ["Directeur des achats", "les achats consommés", "achats, rendement matière"],
    ["Directeur supply chain ou logistique", "les stocks et les transports", "stocks, supply chain et logistique"],
    ["Board, actionnaire ou fonds", "le résultat et sa trajectoire",
     "la lecture d'ensemble, jamais le détail d'atelier"]
  ].freeze

  def self.to_prompt
    LIST.map { |role, line, levers| "- #{role} : porte #{line} — leviers : #{levers}" }.join("\n")
  end
end
