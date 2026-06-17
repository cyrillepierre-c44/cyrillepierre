require "pdf/reader"

# Extracts plain text from an attached source file, for use as LLM input.
class FileTextExtractor
  MAX_TEXT_LENGTH = 8_000

  def self.call(attachment)
    new(attachment).call
  end

  def initialize(attachment)
    @attachment = attachment
  end

  def call
    return nil unless attachment.attached?

    text = attachment.content_type == "application/pdf" ? extract_pdf_text : attachment.download
    text.to_s.truncate(MAX_TEXT_LENGTH, omission: "")
  end

  private

  attr_reader :attachment

  def extract_pdf_text
    attachment.open do |file|
      reader = PDF::Reader.new(file.path)
      reader.pages.map(&:text).join("\n")
    end
  end
end
