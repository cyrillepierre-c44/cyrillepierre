require "test_helper"

class RealisationCatalogTest < ActiveSupport::TestCase
  test "find returns the matching realisation" do
    assert_equal "N°05", RealisationCatalog.find("N°05")[:id]
  end

  test "find returns nil for an unknown id" do
    assert_nil RealisationCatalog.find("N°99")
  end

  test "pick_unused avoids excluded ids" do
    all_ids = RealisationCatalog::ITEMS.map { |r| r[:id] }
    exclude = all_ids - ["N°05"]

    assert_equal "N°05", RealisationCatalog.pick_unused(exclude_ids: exclude)
  end

  test "pick_unused falls back to the full catalogue when everything is excluded" do
    all_ids = RealisationCatalog::ITEMS.map { |r| r[:id] }

    assert_includes all_ids, RealisationCatalog.pick_unused(exclude_ids: all_ids)
  end
end
