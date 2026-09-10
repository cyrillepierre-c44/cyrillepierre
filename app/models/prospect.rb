# Colonne vertébrale commerciale : ce que l'assistant de contact collecte déjà (défi, secteur,
# taille, résumé) n'existait que dans un mail. Un prospect le persiste pour qu'il devienne
# suivable — statut, dernière interaction, prochaine action, date de relance.
class Prospect < ApplicationRecord
  # Optionnel : les demandes venues du site n'ont pas d'utilisateur connecté à ce moment-là.
  # Elles sont visibles des admins via ProspectPolicy::Scope.
  belongs_to :user, optional: true

  SOURCES = {
    site_contact: "Formulaire du site",
    reseau: "Réseau personnel",
    linkedin: "LinkedIn",
    soce: "Soce (Arts et Métiers)",
    wagon: "Le Wagon",
    rebonds: "60 000 rebonds",
    recommandation: "Recommandation",
    autre: "Autre"
  }.freeze

  # L'ordre est celui du pipeline : de la prise de contact à l'issue de l'affaire.
  STATUSES = {
    nouveau: "Nouveau",
    a_contacter: "À contacter",
    en_discussion: "En discussion",
    proposition: "Proposition envoyée",
    gagne: "Gagné",
    perdu: "Perdu",
    en_veille: "En veille"
  }.freeze

  OPEN_STATUSES = %w[nouveau a_contacter en_discussion proposition].freeze

  # Durée annoncée dans /politique-de-confidentialite : trois ans après le dernier contact.
  # Modifier l'une sans l'autre rendrait la page fausse (voir ProspectPurgeJob).
  RETENTION = 3.years

  enum :source, SOURCES.keys.each_with_index.to_h, prefix: true
  enum :status, STATUSES.keys.each_with_index.to_h

  validates :name, presence: true

  before_validation :normalize_themes

  scope :ouverts, -> { where(status: OPEN_STATUSES) }
  scope :en_retard, -> { where(next_action_on: ..Date.current) }
  # `last_contact_at` peut être vide sur une fiche saisie à la main et jamais travaillée :
  # la date de création fait alors foi, sinon la piste ne serait jamais purgée.
  scope :expired, -> { where("COALESCE(last_contact_at, created_at) < ?", RETENTION.ago) }
  scope :pipeline_order, -> { order(Arel.sql("next_action_on ASC NULLS LAST"), updated_at: :desc) }

  # Alimenté par ContactsController#create : le visiteur a déjà répondu aux trois questions
  # de l'assistant, tout est là. Le nom peut manquer sur une soumission dégradée — on retombe
  # sur l'email puis l'entreprise plutôt que de perdre la piste.
  def self.record_contact_request(attributes)
    themes = Array(attributes[:themes]).map(&:to_s)
    fallback = attributes[:email].presence || attributes[:company].presence || "Contact sans nom"

    create!(
      name: attributes[:name].presence || fallback,
      email: attributes[:email],
      company: attributes[:company],
      phone: attributes[:phone],
      sector: attributes[:sector],
      company_size: attributes[:size],
      themes: themes,
      summary: attributes[:summary],
      conversation: attributes[:conversation],
      visitor_precision: attributes[:precision],
      source: :site_contact,
      status: :nouveau,
      last_contact_at: Time.current
    )
  end

  def source_label
    SOURCES.fetch(source.to_sym, source)
  end

  def status_label
    STATUSES.fetch(status.to_sym, status)
  end

  def open?
    status.in?(OPEN_STATUSES)
  end

  # Une relance est due le jour même, pas seulement passée : c'est ce qui remonte en tête du
  # pipeline le matin.
  def relance_due?
    open? && next_action_on.present? && next_action_on <= Date.current
  end

  # Brief pré-rempli pour le générateur de proposition commerciale : le besoin du prospect a
  # déjà été qualifié par l'assistant, le retaper à la main serait absurde.
  def brief_for_proposal
    lines = []
    lines << "Client : #{company}" if company.present?
    lines << "Secteur : #{sector}" if sector.present?
    lines << "Taille : #{company_size}" if company_size.present?
    lines << "Thèmes : #{themes_text}" if themes.any?
    lines << "\nBesoin exprimé :\n#{summary}" if summary.present?
    lines << "\nPrécisions :\n#{visitor_precision}" if visitor_precision.present?
    lines << "\nNotes internes :\n#{notes}" if notes.present?
    lines.join("\n")
  end

  def display_company
    company.presence || "—"
  end

  def themes_text
    themes.join(", ")
  end

  def themes_text=(value)
    self.themes = value.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  private

  def normalize_themes
    self.themes = Array(themes).map { |theme| theme.to_s.strip }.reject(&:blank?)
  end
end
