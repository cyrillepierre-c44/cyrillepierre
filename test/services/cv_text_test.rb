require "test_helper"

class CvTextTest < ActiveSupport::TestCase
  setup { Rails.cache.delete(CvText::CACHE_KEY) }
  teardown { Rails.cache.delete(CvText::CACHE_KEY) }

  test "extracts the plain text of the public CV page" do
    text = CvText.call

    assert text.present?
    assert_includes text, "Cyrille"
  end

  # Le but du service : ne pas dépendre d'un CV recopié à la main, mais du contenu réellement
  # affiché sur /cv. Le balisage et les scripts ne doivent pas se retrouver dans le prompt.
  test "strips markup, scripts and styles" do
    text = CvText.call

    assert_not_includes text, "<div"
    assert_not_includes text, "function"
    assert_not_includes text, "@media"
  end

  test "collapses whitespace into a single line" do
    text = CvText.call

    assert_not_includes text, "\n"
    assert_no_match(/\s{2,}/, text)
  end

  test "does not include the toolbar buttons of the page" do
    text = CvText.call

    assert_not_includes text, "Version papier"
    assert_not_includes text, "Imprimer"
  end
end
