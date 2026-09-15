require "test_helper"

# Cloudinary rend un fichier réencodé, donc d'un autre checksum que celui enregistré au dépôt :
# ActiveStorage::AnalyzeJob échouait sur chaque visuel généré, sans qu'aucune métadonnée ne serve
# nulle part dans l'application.
class ActiveStorageAnalysisTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "analysis is disabled, so no job chases a checksum Cloudinary will never return" do
    assert_empty Rails.application.config.active_storage.analyzers
  end

  test "attaching a visual enqueues no analysis job" do
    user = User.create!(email: "analyse@example.com", password: "password123")
    generation = Generation.create!(user: user, kind: :linkedin_post, output: "Un post.")

    assert_no_enqueued_jobs(only: ActiveStorage::AnalyzeJob) do
      generation.visual.attach(io: StringIO.new("des octets"), filename: "visual.png",
                               content_type: "image/png")
    end

    assert generation.visual.attached?
  end
end
