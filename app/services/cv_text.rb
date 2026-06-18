# Extracts the plain-text content of the public /cv page, so the content generator
# always uses the same up-to-date CV the rest of the site shows — no manual re-upload needed.
class CvText
  CACHE_KEY = "cv_text/v1"

  def self.call
    Rails.cache.fetch(CACHE_KEY, expires_in: 1.hour) do
      html = ApplicationController.renderer.render(template: "pages/cv", layout: false)
      doc = Nokogiri::HTML(html)
      doc.css("script, style, .btn-bar").remove
      doc.text.to_s.squish
    end
  end
end
