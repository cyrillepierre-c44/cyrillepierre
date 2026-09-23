require "test_helper"

# Une page n'a de date que si son adresse la porte ou si le texte l'écrit : la date dite par
# le modèle ne vaut rien seule, et une page muette reste non datée.
class PageDateTest < ActiveSupport::TestCase
  test "reads a date from the address in its three usual forms, and nothing from an id" do
    assert_equal Date.new(2022, 1, 5), PageDate.from_url("https://www.mapei.com/fr/actualite/2022/01/05/mapei-france-acquiert")
    assert_equal Date.new(2024, 2, 21), PageDate.from_url("https://www.la-gazette-eco.fr/article/MAPEI-SAINT-VULBAS-21022024")
    assert_equal Date.new(2024, 2, 12), PageDate.from_url("https://example.com/news/2024-02-12-mapei")
    assert_nil PageDate.from_url("https://www.batiactu.com/edito/mapei-ouvre-sa-troisieme-usine-en-france-37634.php")
    assert_nil PageDate.from_url("https://bebee.com/fr/jobs/directeur-dunite-fj-2354169264")
    assert_nil PageDate.from_url("https://example.com/a/99999999")
    assert_nil PageDate.from_url("http://exa mple.com/2022/01/05/")
  end

  test "keeps the model's date only when the page writes it, in any common spelling, and never in the future" do
    travel_to Time.zone.local(2026, 9, 23, 12) do
      assert_equal Date.new(2015, 11, 24), PageDate.read("2015-11-24", "Publié le 24/11/2015 par la rédaction")
      assert_equal Date.new(2016, 1, 8), PageDate.read("2016-01-08", "Le 8 janvier 2016, Mapei annonce")
      assert_equal Date.new(2016, 1, 8), PageDate.read("2016-01-08", "08 janvier 2016")
      assert_equal Date.new(2024, 3, 1), PageDate.read("2024-03-01", "1er mars 2024")
      assert_equal Date.new(2020, 11, 16), PageDate.read("2020-11-16", "November 16, 2020")
      assert_equal Date.new(2020, 11, 16), PageDate.read("2020-11-16", "16 November 2020")
      assert_equal Date.new(2020, 11, 16), PageDate.read("2020-11-16", "datePublished: 2020-11-16T08:00")
      assert_equal Date.new(2020, 2, 3), PageDate.read("2020-02-03", "Mis à jour le 3/2/2020")
      assert_nil PageDate.read("2015-11-24", "Publié le 25/11/2015"), "another day is not this date"
      assert_nil PageDate.read("2027-01-01", "1er janvier 2027"), "a future date is a mistake"
      assert_nil PageDate.read("pas une date", "24/11/2015")
      assert_nil PageDate.read("", "24/11/2015")
      assert_nil PageDate.read("2015-11-24", nil)
    end
  end
end
