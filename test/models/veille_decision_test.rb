require "test_helper"

class VeilleDecisionTest < ActiveSupport::TestCase
  test "two spellings of the same company share a key" do
    assert_equal "nicoll", VeilleDecision.company_key("Nicoll — usine de Frontonas (38)")
    assert_equal "nicoll", VeilleDecision.company_key("Nicoll (groupe Aliaxis) — site de Frontonas")
    assert_equal "mapei france", VeilleDecision.company_key("  MAPEI France  ")
  end

  test "renders the memory as prompt text, most recent first, with the fiche and the reason" do
    admin = User.create!(email: "memo-admin@example.com", password: "password123", role: :admin)
    fiche = Prospect.create!(name: "Décideur à identifier", company: "Nicoll — Frontonas", user: admin)
    travel_to Time.zone.local(2026, 9, 23, 10) do
      VeilleDecision.create!(decision: :kept, company: "Nicoll — Frontonas", signal_type: "annonce",
                             source_name: "Indeed", reason: "Poste ouvert depuis juillet, site à 40 km", prospect: fiche, user: admin)
    end
    travel_to Time.zone.local(2026, 9, 28, 8) do
      VeilleDecision.create!(decision: :dismissed, company: "Acurion (ex-JTEKT) — Irigny", signal_type: "cession", user: admin)
    end

    text = VeilleDecision.to_prompt

    assert_includes text, "Mémoire de tri de Cyrille (2 décisions"
    lines = text.lines.map(&:strip).select { |l| l.start_with?("- ") }
    assert_equal "- 28/09/2026 · Acurion (ex-JTEKT) — Irigny · cession · ÉCARTÉ : sans raison notée", lines.first
    assert_equal "- 23/09/2026 · Nicoll — Frontonas · annonce · Indeed · RETENU, fiche ##{fiche.id} : Poste ouvert depuis juillet, site à 40 km",
                 lines.last
  end

  test "says so when the memory is empty" do
    assert_includes VeilleDecision.to_prompt, "aucune décision"
  end
end
