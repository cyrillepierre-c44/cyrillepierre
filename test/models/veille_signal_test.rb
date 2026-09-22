require "test_helper"

class VeilleSignalTest < ActiveSupport::TestCase
  setup do
    @admin = User.create!(email: "veille-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
    @signal = VeilleSignal.create!(
      run_week: Date.new(2026, 9, 28), rank: 1, company: "MAPEI — Saint-Vulbas", location: "Saint-Vulbas (01)",
      sector: "Chimie du bâtiment", signal_type: "annonce", signal: "Directeur d'Unité, Indeed, 12 jours",
      source_name: "Indeed", source_url: "https://to.indeed.com/aatjt4vm66nl", published_on: Date.new(2026, 9, 9),
      why_now: "Un poste de direction vacant.", comparable: "N°16 — refonte du management de proximité",
      pitch: "Bonjour, j'ai vu sur Indeed…"
    )
  end

  test "a signal needs a known type, a company, a text and a unique source per week" do
    assert_not VeilleSignal.new(run_week: Date.current, company: "X", signal: "s", source_url: "u", signal_type: "rumeur").valid?
    dup = VeilleSignal.new(@signal.attributes.except("id", "created_at", "updated_at"))
    assert_not dup.valid?
    dup.run_week = Date.new(2026, 10, 5)
    assert dup.valid?
  end

  test "keeping a signal creates the prospect Cyrille used to type by hand, and links it" do
    travel_to Date.new(2026, 9, 28) do
      prospect = @signal.keep!(@admin)

      assert @signal.reload.kept?
      assert_equal prospect, @signal.prospect
      assert_equal @admin, prospect.user
      assert prospect.source_veille?
      assert prospect.a_contacter?
      assert_equal "MAPEI — Saint-Vulbas", prospect.company
      assert_equal "Décideur à identifier", prospect.name
      assert_equal Date.new(2026, 9, 29), prospect.next_action_on
      assert_includes prospect.notes, "SIGNAL (veille du 28/09/2026, type annonce) : Directeur d'Unité, Indeed, 12 jours"
      assert_includes prospect.notes, "Source : Indeed, 09/09/2026 — https://to.indeed.com/aatjt4vm66nl"
      assert_includes prospect.notes, "Comparable catalogue : N°16"
      assert_includes prospect.notes, "Accroche proposée : « Bonjour, j'ai vu sur Indeed… »"
      assert_includes prospect.notes, "Interlocuteur à identifier"
    end
  end

  test "dismissing keeps the signal for memory without a prospect" do
    @signal.dismiss!

    assert @signal.dismissed?
    assert_nil @signal.prospect
  end

  test "deleting the prospect does not delete the signal" do
    @signal.keep!(@admin).destroy!

    assert @signal.reload.kept?
    assert_nil @signal.prospect
  end

  test "age and labels" do
    travel_to Date.new(2026, 9, 21) do
      assert_equal 12, @signal.age_days
      assert_equal "Annonce", @signal.type_label
      assert_equal "Veille automatique", @signal.keep!(@admin).source_label
    end
  end
end
