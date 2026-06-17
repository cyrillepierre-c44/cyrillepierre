class Generation < ApplicationRecord
  ALLOWED_FILE_TYPES = %w[text/plain text/markdown application/pdf].freeze
  MAX_FILE_SIZE = 10.megabytes

  belongs_to :user
  has_one_attached :source_file

  enum :kind, { linkedin_post: 0, job_application: 1, site_actu: 2 }
  enum :status, { draft: 0, generated: 1, published: 2 }

  validates :kind, presence: true
  validate :source_file_is_acceptable

  scope :published_site_actus, -> { where(kind: :site_actu, status: :published).order(published_at: :desc) }

  def publishable?
    site_actu?
  end

  private

  def source_file_is_acceptable
    return unless source_file.attached?

    unless source_file.content_type.in?(ALLOWED_FILE_TYPES)
      errors.add(:source_file, "doit être un fichier texte, markdown ou PDF")
    end

    return unless source_file.byte_size > MAX_FILE_SIZE

    errors.add(:source_file, "doit faire moins de 10 Mo")
  end
end
