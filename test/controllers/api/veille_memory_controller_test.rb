require "test_helper"

module Api
  class VeilleMemoryControllerTest < ActionDispatch::IntegrationTest
    setup do
      @token = ENV["VEILLE_API_TOKEN"]
      ENV["VEILLE_API_TOKEN"] = "jeton-de-test"
    end

    teardown { ENV["VEILLE_API_TOKEN"] = @token }

    test "rejects a missing or wrong token" do
      get api_veille_memory_path
      assert_response :unauthorized

      get api_veille_memory_path, headers: { "Authorization" => "Bearer faux" }
      assert_response :unauthorized
    end

    test "serves the memory as plain text for the routine" do
      VeilleDecision.create!(decision: :dismissed, company: "MAPEI — Saint-Vulbas", signal_type: "annonce",
                             reason: "Annonce de douze jours, pas un poste vacant")

      get api_veille_memory_path, headers: { "Authorization" => "Bearer jeton-de-test" }

      assert_response :success
      assert_equal "text/plain", @response.media_type
      assert_includes @response.body, "MAPEI — Saint-Vulbas · annonce · ÉCARTÉ : Annonce de douze jours"
    end
  end
end
