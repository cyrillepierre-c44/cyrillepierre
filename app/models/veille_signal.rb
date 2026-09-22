# Un signal déposé par la routine de veille du lundi (voir docs/routine-veille-prompt.md) :
# une entreprise, ce qu'elle montre d'elle-même, la source, la réalisation comparable et
# l'accroche proposée. Il attend la décision de Cyrille dans /studio/veille — retenu, il
# devient une fiche Prospect avec tout cela déjà en notes ; écarté, il reste pour mémoire
# (la routine relit les condensés pour ne pas ressortir la même chose).
class VeilleSignal < ApplicationRecord
  belongs_to :prospect, optional: true

  TYPES = {
    "annonce" => "Annonce",
    "dirigeant" => "Dirigeant",
    "cession" => "Cession",
    "comptes" => "Comptes",
    "rappel" => "Rappel produit",
    "installation_classee" => "Installation classée",
    "aide" => "Aide",
    "presse" => "Presse",
    "cabinet" => "Cabinet"
  }.freeze

  enum :status, { pending: 0, kept: 1, dismissed: 2 }

  validates :run_week, :company, :signal, :source_url, presence: true
  validates :signal_type, inclusion: { in: TYPES.keys }
  validates :source_url, uniqueness: { scope: :run_week }

  scope :shortlist_first, -> { order(shortlisted: :desc, rank: :asc, id: :asc) }

  def type_label
    TYPES.fetch(signal_type, signal_type)
  end

  def age_days
    published_on && (Date.current - published_on).to_i
  end

  # La fiche telle que Cyrille la saisissait à la main après chaque condensé (21/09/2026) :
  # signal, lecture, comparable, accroche, et la même première action pour tous.
  def keep!(user)
    transaction do
      prospect = Prospect.create!(
        user: user, source: :veille, status: :a_contacter, name: "Décideur à identifier",
        company: company, sector: sector, summary: signal, notes: prospect_notes,
        next_action: "Identifier l'interlocuteur (LinkedIn), lire la source, envoyer l'accroche",
        next_action_on: Date.current.next_weekday
      )
      update!(status: :kept, prospect: prospect)
      prospect
    end
  end

  def dismiss!
    update!(status: :dismissed)
  end

  def prospect_notes
    lines = ["SIGNAL (veille du #{run_week.strftime('%d/%m/%Y')}, type #{type_label.downcase}) : #{signal}"]
    lines << "Source : #{[source_name, published_on&.strftime('%d/%m/%Y')].compact.join(', ')} — #{source_url}"
    lines << "Lieu : #{location}" if location.present?
    lines << "Lecture : #{why_now}" if why_now.present?
    lines << "Comparable catalogue : #{comparable}" if comparable.present?
    lines << "Accroche proposée : « #{pitch} »" if pitch.present?
    lines << "Interlocuteur à identifier : DRH, directeur industriel ou directeur de site (LinkedIn), " \
             "jamais le poste vacant lui-même."
    lines.join("\n")
  end
end
