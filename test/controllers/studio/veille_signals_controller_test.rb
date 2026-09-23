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
      assert_select ".veille-signal--young form[action=?]", keep_studio_veille_signal_path(@signal)
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
      assert_select "form[action=?]", keep_studio_veille_signal_path(@signal)
    end

    test "keeping creates the prospect and moves the signal to the recent list" do
      sign_in @admin

      assert_difference("Prospect.count", 1) do
        patch keep_studio_veille_signal_path(@signal)
      end

      assert_redirected_to studio_veille_signals_path
      prospect = @signal.reload.prospect
      assert_equal @admin, prospect.user
      assert_includes prospect.notes, "Accroche proposée"
      follow_redirect!
      assert_select ".veille-signal", 1
      assert_select "a[href=?]", studio_prospect_path(prospect), text: "fiche ##{prospect.id}"
    end

    test "dismissing keeps the signal for memory, and a settled signal cannot be settled again" do
      sign_in @admin

      patch dismiss_studio_veille_signal_path(@other)
      assert @other.reload.dismissed?

      patch keep_studio_veille_signal_path(@other)
      assert_response :not_found
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
