require "test_helper"

module Studio
  class VeilleSignalsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = User.create!(email: "veille-admin@example.com", password: "password123", role: :admin)
      @editor = User.create!(email: "veille-editor@example.com", password: "password123", role: :editor)
      @signal = VeilleSignal.create!(run_week: Date.new(2026, 9, 28), rank: 1, company: "MAPEI — Saint-Vulbas",
                                     signal_type: "annonce", signal: "Directeur d'Unité", source_name: "Indeed",
                                     source_url: "https://to.indeed.com/a", pitch: "Bonjour, j'ai vu sur Indeed…")
      @other = VeilleSignal.create!(run_week: Date.new(2026, 9, 28), shortlisted: false, company: "Medtronic",
                                    signal_type: "annonce", signal: "Ingénieur", source_url: "https://to.indeed.com/b")
    end

    test "an announcement younger than six weeks is greyed, dated, and listed after the real signals" do
      @signal.update!(published_on: Date.new(2026, 9, 9))
      sign_in @admin

      travel_to Date.new(2026, 9, 21) do
        get studio_veille_signals_path
      end

      assert_response :success
      assert_select ".veille-signal--young", 1
      assert_select ".veille-signal--young .studio-card-title", text: /MAPEI/
      assert_select ".veille-signal--young .veille-signal-young-note", text: /ne compte comme signal qu'au 21\/10\/2026/
      assert_select ".veille-signal:first-of-type .studio-card-title", text: /Medtronic/, count: 1
      assert_select ".veille-signal--young button[data-url=?]", keep_studio_veille_signal_path(@signal)
    end

    test "the page requires an admin" do
      get studio_veille_signals_path
      assert_redirected_to new_user_session_path

      sign_in @editor
      get studio_veille_signals_path
      assert_redirected_to root_path
    end

    test "lists the pending signals, shortlist first, with their pitch to copy" do
      sign_in @admin

      get studio_veille_signals_path

      assert_response :success
      assert_select ".veille-signal", 2
      assert_select ".veille-signal:first-of-type .studio-card-title", text: /1\s*MAPEI/
      assert_select ".veille-signal--other", 1
      assert_select "pre.studio-output", text: "Bonjour, j'ai vu sur Indeed…"
      assert_select "a.veille-source-link[href=?]", "https://to.indeed.com/a"
      assert_select "button[data-url=?][data-method=patch]", keep_studio_veille_signal_path(@signal)
      assert_select "button[data-url=?][data-method=patch]", dismiss_studio_veille_signal_path(@signal)
      assert_select "dialog.studio-dialog textarea[name=reason]", 1
    end

    test "keeping creates the prospect, records the reason, and shows it in the memory" do
      sign_in @admin

      assert_difference([ "Prospect.count", "VeilleDecision.kept.count" ], 1) do
        patch keep_studio_veille_signal_path(@signal), params: { reason: "Poste ouvert depuis juillet" }
      end

      assert_redirected_to studio_veille_signals_path
      prospect = @signal.reload.prospect
      assert_equal @admin, prospect.user
      assert_includes prospect.notes, "Accroche proposée"
      decision = VeilleDecision.last
      assert_equal "Poste ouvert depuis juillet", decision.reason
      assert_equal prospect, decision.prospect
      assert_equal @signal, decision.veille_signal
      follow_redirect!
      assert_select ".veille-signal", 1
      assert_select ".veille-decision a[href=?]", studio_prospect_path(prospect), text: "fiche ##{prospect.id}"
      assert_select ".veille-decision textarea", text: "Poste ouvert depuis juillet"
    end

    test "dismissing records the reason, and a settled signal cannot be settled again" do
      sign_in @admin

      patch dismiss_studio_veille_signal_path(@other), params: { reason: "Ingénieur, pas un poste de direction" }
      assert @other.reload.dismissed?
      assert_equal "Ingénieur, pas un poste de direction", VeilleDecision.dismissed.last.reason

      patch keep_studio_veille_signal_path(@other)
      assert_response :not_found
    end

    test "a blank reason is stored as none" do
      sign_in @admin

      patch dismiss_studio_veille_signal_path(@other), params: { reason: "  " }

      assert_nil VeilleDecision.last.reason
    end

    # Le 28/09/2026, Nicoll est ressorti en rang 3 alors que la fiche #44 existait depuis le 23 :
    # l'adresse Indeed avait changé, la routine ne l'a pas reconnu. La page, elle, le sait.
    test "a company already settled another week is greyed, with the earlier decision and its reason" do
      earlier = VeilleSignal.create!(run_week: Date.new(2026, 9, 21), company: "Medtronic — Trévoux (01)",
                                     signal_type: "annonce", signal: "Directeur de site", source_url: "https://to.indeed.com/old")
      fiche = earlier.keep!(@admin, reason: "Site sans pilote depuis juillet")
      sign_in @admin

      get studio_veille_signals_path

      assert_select ".veille-signal--seen", 1
      assert_select ".veille-signal--seen .studio-card-title", text: /Medtronic/
      assert_select ".veille-signal--seen .veille-signal-seen-note", text: /déjà tranchée le 28\/09\/2026 : retenu/
      assert_select ".veille-signal--seen .veille-signal-seen-note a[href=?]", studio_prospect_path(fiche)
      assert_select ".veille-signal--seen .veille-signal-seen-note", text: /Site sans pilote depuis juillet/
      assert_select ".veille-signal:first-of-type .studio-card-title", text: /MAPEI/
    end

    test "a reason can be corrected afterwards, by an admin only" do
      decision = VeilleDecision.create!(decision: :dismissed, company: "Acurion — Irigny", user: @admin)

      sign_in @editor
      patch studio_veille_decision_path(decision), params: { veille_decision: { reason: "x" } }
      assert_response :not_found

      sign_in @admin
      patch studio_veille_decision_path(decision), params: { veille_decision: { reason: "Cession à un fonds : trop tôt" } }
      assert_redirected_to studio_veille_signals_path
      assert_equal "Cession à un fonds : trop tôt", decision.reload.reason
    end

    test "an editor can neither keep nor dismiss" do
      sign_in @editor

      patch keep_studio_veille_signal_path(@signal)

      assert_response :not_found
      assert @signal.reload.pending?
    end

    test "the pipeline shows the number of signals waiting" do
      sign_in @admin

      get studio_prospects_path

      assert_select "a[href=?]", studio_veille_signals_path, text: "Veille (2)"
    end
  end
end
