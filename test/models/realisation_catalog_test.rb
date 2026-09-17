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


  # --- la page /realisations ----------------------------------------------------------------

  # Une réalisation ajoutée au catalogue sans être placée dans une section n'apparaîtrait
  # jamais sur la page, sans erreur ; placée deux fois, elle s'y répéterait.
  test "every realisation sits in exactly one page section" do
    placed = RealisationCatalog::PAGE_SECTIONS.flat_map { |section| section[:ids] }

    assert_equal RealisationCatalog::ITEMS.map { |r| r[:id] }.sort, placed.sort
    assert_equal placed.uniq, placed
  end

  # Les trois se créent ensemble : les données de page, l'illustration SVG et le visual_hint
  # qui la décrit au générateur de visuels. La règle était orale, elle est maintenant testée.
  test "every realisation has its page data, its illustration partial and its visual hint" do
    RealisationCatalog::ITEMS.each do |item|
      page = item[:page]
      assert page.present?, "#{item[:id]} : pas de données de page"
      assert page[:company].present?, "#{item[:id]} : pas d'entreprise affichée"
      assert page[:icon].to_s.start_with?("fa-"), "#{item[:id]} : icône manquante"
      assert page[:description].present? || page[:pivots].present?, "#{item[:id]} : ni description ni pivots"
      assert item[:visual_hint].present?, "#{item[:id]} : pas de visual_hint"
      partial = Rails.root.join("app/views/#{RealisationCatalog.illustration_partial(item).sub(%r{/(n\d\d)$}, '/_\\1')}.html.erb")
      assert partial.exist?, "#{item[:id]} : illustration absente (#{partial})"
    end
  end

  test "page title and result fall back on the catalogue wording" do
    item = { id: "N°99", titre: "Titre catalogue", resultat: "Résultat catalogue", page: {} }
    overridden = item.merge(page: { title: "Titre public", result: "Résultat public" })

    assert_equal "Titre catalogue", RealisationCatalog.page_title(item)
    assert_equal "Résultat catalogue", RealisationCatalog.page_result(item)
    assert_equal "Titre public", RealisationCatalog.page_title(overridden)
    assert_equal "Résultat public", RealisationCatalog.page_result(overridden)
  end

  test "each realisation has a public anchor on the realisations page" do
    item = RealisationCatalog.find("N°07")

    assert_equal "n07", RealisationCatalog.anchor(item)
    assert_equal "https://www.cyrillepierre.com/realisations#n07", RealisationCatalog.public_url(item)
  end
end
