require "pdf/reader"

# Extracts plain text from an attached source file, for use as LLM input.
class FileTextExtractor
  # Une analyse financière complète fait près de 9 000 caractères : à 8 000, sa conclusion partait
  # sans un mot, et la note de diagnostic ne la voyait jamais.
  MAX_TEXT_LENGTH = 40_000

  def self.call(attachment)
    new(attachment).call
  end

  def initialize(attachment)
    @attachment = attachment
  end

  def call
    return nil unless attachment.attached?

    text = attachment.content_type == "application/pdf" ? extract_pdf_text : downloaded_text
    text.to_s.truncate(MAX_TEXT_LENGTH, omission: "")
  end

  private

  attr_reader :attachment

  # Active Storage rend des octets sans encodage : concaténés au prompt UTF-8, le premier accent
  # d'une analyse en français levait « incompatible character encodings » et la génération échouait.
  def downloaded_text
    attachment.download.dup.force_encoding(Encoding::UTF_8).scrub
  end

  def extract_pdf_text
    attachment.open do |file|
      reader = PDF::Reader.new(file.path)
      reader.pages.map(&:text).join("\n")
    end
  end
end
