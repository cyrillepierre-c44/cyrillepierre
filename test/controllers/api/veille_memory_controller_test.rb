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

    # Le 05/10/2026, Hermès (#39, saisie à la main) est ressorti en signal neuf et Bayer (#41) a été
    # écarté au nom de la chimie : la routine ne voyait que les décisions, pas les fiches.
    test "also lists the fiches already in the pipeline" do
      fiche = Prospect.create!(name: "Décideur à identifier", company: "Hermès — atelier d'Irigny",
                               status: :a_contacter)

      get api_veille_memory_path, headers: { "Authorization" => "Bearer jeton-de-test" }

      assert_includes @response.body, "aucune décision"
      assert_includes @response.body, "fiche ##{fiche.id} · Hermès — atelier d'Irigny · À contacter"
    end
  end
end
