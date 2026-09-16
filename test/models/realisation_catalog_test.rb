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


  # --- rendu vers les prompts ---------------------------------------------------------------

  # Le périmètre sémantique est la seule chose qui empêche un modèle de rattacher un chiffre au
  # sujet voisin : il doit sortir dans les trois formes, sinon on retrouve les articles faux du
  # 11/09/2026.
  test "every prompt style carries the semantic scope of the realisations that have one" do
    scoped = RealisationCatalog::ITEMS.select { |r| r[:semantic_scope].present? }
    assert scoped.any?

    RealisationCatalog::PROMPT_STYLES.each do |style|
      rendered = RealisationCatalog.to_prompt(style)
      scoped.each { |r| assert_includes rendered, "⚠ Périmètre : #{r[:semantic_scope]}", style }
    end
  end

  test "the anonymized style never names a company where the named style does" do
    named = RealisationCatalog.to_prompt(:named)
    anonymized = RealisationCatalog.to_prompt(:anonymized)

    assert_includes named, "Yoplait"
    assert_not_includes anonymized, "Yoplait"
    assert_includes anonymized, "usine industrielle automatisée"
  end

  test "the detailed style gives the contact assistant the tags it filters on" do
    detailed = RealisationCatalog.to_prompt(:detailed)

    assert_includes detailed, "[tags:"
    assert_includes detailed, "Contexte :"
    assert_includes detailed, "Réalisation :"
  end

  test "an unknown prompt style is refused rather than rendered empty" do
    assert_raises(ArgumentError) { RealisationCatalog.to_prompt(:markdown) }
  end
end
