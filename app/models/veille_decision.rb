# Une décision de tri de Cyrille et sa raison, dans ses mots (28/09/2026) : « Retenir » ou
# « Écarter » un signal sur /studio/veille, ou supprimer une fiche prospect. C'est la mémoire que
# la routine du lundi relit avant de chercher (GET /api/veille_memory, voir
# docs/routine-veille-prompt.md) : une entreprise déjà tranchée ne revient que s'il y a du nouveau,
# et une raison qui ressemble à une règle générale s'applique à tous les signaux de la semaine.
# La table est indépendante des signaux et des fiches : la raison survit à leur suppression.
class VeilleDecision < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :veille_signal, optional: true
  belongs_to :prospect, optional: true

  enum :decision, { kept: 0, dismissed: 1, deleted: 2 }

  LABELS = { "kept" => "Retenu", "dismissed" => "Écarté", "deleted" => "Supprimé" }.freeze

  validates :company, presence: true

  before_validation { self.company_key = self.class.company_key(company) }

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  # Même délai que les fiches : c'est ce que la politique de confidentialité annonce.
  scope :expired, -> { where(created_at: ...Prospect::RETENTION.ago) }

  # « Nicoll (groupe Aliaxis) — site de Frontonas » et « Nicoll — usine de Frontonas (38) » désignent
  # la même entreprise : on compare ce qui précède le premier tiret ou la première parenthèse,
  # comme ProspectEnricher le fait pour l'annuaire.
  def self.company_key(name)
    name.to_s.split(/\s+[—–-]\s+|\(/).first.to_s.squish.downcase
  end

  def self.for_company(name)
    where(company_key: company_key(name))
  end

  # Ce que la routine lit. Texte brut, la plus récente en premier, bornée pour que le prompt ne
  # gonfle pas avec les années.
  def self.to_prompt(limit: 200)
    decisions = recent_first.limit(limit).includes(:prospect)
    return "Mémoire de tri de Cyrille : aucune décision enregistrée pour l'instant." if decisions.empty?

    lines = ["Mémoire de tri de Cyrille (#{decisions.size} décisions, la plus récente en premier). Une entreprise " \
             "déjà tranchée ne revient que s'il y a du nouveau, et la fiche dit alors ce qui avait été décidé. " \
             "Une raison qui ressemble à une règle générale s'applique à tous les signaux de la semaine."]
    decisions.each { |decision| lines << "- #{decision.to_line}" }
    lines.join("\n")
  end

  def label
    LABELS.fetch(decision)
  end

  def to_line
    parts = [created_at.in_time_zone("Europe/Paris").strftime("%d/%m/%Y"), company]
    parts << signal_type if signal_type.present?
    parts << source_name if source_name.present?
    verdict = label.upcase
    verdict += ", fiche ##{prospect_id}" if prospect_id.present? && !deleted?
    "#{parts.join(' · ')} · #{verdict} : #{reason.presence || 'sans raison notée'}"
  end
end
