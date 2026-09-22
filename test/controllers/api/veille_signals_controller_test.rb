require "test_helper"

module Api
  class VeilleSignalsControllerTest < ActionDispatch::IntegrationTest
    PAYLOAD = {
      week: "2026-09-28",
      signals: [
        { rank: 1, shortlisted: true, company: "MAPEI — Saint-Vulbas", location: "Saint-Vulbas (01)",
          sector: "Chimie du bâtiment", signal_type: "annonce", signal: "Directeur d'Unité, Indeed",
          source_name: "Indeed", source_url: "https://to.indeed.com/aatjt4vm66nl", published_on: "2026-09-09",
          why_now: "Poste vacant.", comparable: "N°16 — management de proximité", pitch: "Bonjour…" },
        { rank: nil, shortlisted: false, company: "Medtronic — Trévoux", signal_type: "annonce",
          signal: "Ingénieur performance, 89 j", source_url: "https://to.indeed.com/aapbgxn4zzpn" }
      ]
    }.freeze

    setup do
      @token = ENV["VEILLE_API_TOKEN"]
      ENV["VEILLE_API_TOKEN"] = "jeton-de-test"
    end

    teardown { ENV["VEILLE_API_TOKEN"] = @token }

    def post_signals(payload = PAYLOAD, token: "jeton-de-test")
      post api_veille_signals_path, params: payload.to_json,
                                    headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
    end

    test "rejects a missing or wrong token, and a missing configuration" do
      post_signals(token: "faux")
      assert_response :unauthorized
      assert_equal 0, VeilleSignal.count

      ENV["VEILLE_API_TOKEN"] = nil
      post_signals(token: "")
      assert_response :unauthorized
    end

    test "stores the signals of a week and tells where to validate them" do
      post_signals

      assert_response :created
      body = response.parsed_body
      assert_equal 2, body["received"]
      assert_equal 2, body["created"]
      assert_equal studio_veille_signals_url, body["validate_at"]
      signal = VeilleSignal.find_by!(source_url: "https://to.indeed.com/aatjt4vm66nl")
      assert_equal Date.new(2026, 9, 28), signal.run_week
      assert_equal Date.new(2026, 9, 9), signal.published_on
      assert signal.shortlisted?
      assert_not VeilleSignal.find_by!(company: "Medtronic — Trévoux").shortlisted?
    end

    test "sending the same batch twice updates instead of duplicating, and never reopens a decision" do
      post_signals
      VeilleSignal.find_by!(company: "Medtronic — Trévoux").dismiss!
      changed = PAYLOAD.deep_dup
      changed[:signals][0][:pitch] = "Accroche revue"
      changed[:signals][1][:pitch] = "Ne doit pas réapparaître"

      post_signals(changed)

      assert_response :created
      assert_equal({ "received" => 2, "created" => 0, "updated" => 2 }, response.parsed_body.slice("received", "created", "updated"))
      assert_equal 2, VeilleSignal.count
      assert_equal "Accroche revue", VeilleSignal.find_by!(company: "MAPEI — Saint-Vulbas").pitch
      dismissed = VeilleSignal.find_by!(company: "Medtronic — Trévoux")
      assert dismissed.dismissed?
      assert_nil dismissed.pitch
    end

    test "an invalid signal or a malformed payload is refused with a reason" do
      bad = PAYLOAD.deep_dup
      bad[:signals][0][:signal_type] = "rumeur"
      post_signals(bad)
      assert_response :unprocessable_entity
      assert_includes response.parsed_body["error"], "Signal type"

      post_signals({ week: "pas-une-date", signals: [] })
      assert_response :bad_request

      post_signals({ signals: [] })
      assert_response :bad_request
    end
  end
end
