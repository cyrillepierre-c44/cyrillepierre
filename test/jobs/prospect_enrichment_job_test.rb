require "test_helper"

class ProspectEnrichmentJobTest < ActiveJob::TestCase
  setup do
    user = User.create!(email: "job-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @prospect = Prospect.create!(user: user, name: "X", company: "Aldes", enrichment_requested_at: Time.current)
  end

  test "writes the enrichment, the siren and the date on the sheet" do
    ProspectEnricher.stub(:call, ProspectEnricher::Result.new("IDENTITÉ : Aldes", "123456789")) do
      ProspectEnrichmentJob.perform_now(@prospect)
    end

    @prospect.reload
    assert_equal "IDENTITÉ : Aldes", @prospect.enrichment
    assert_equal "123456789", @prospect.siren
    assert @prospect.enriched?
    assert_not @prospect.enriching?
  end

  test "a failure is written on the sheet instead of being lost" do
    ProspectEnricher.stub(:call, ->(_) { raise Net::OpenTimeout, "trop long" }) do
      ProspectEnrichmentJob.perform_now(@prospect)
    end

    assert_includes @prospect.reload.enrichment, "Enrichissement impossible : Net::OpenTimeout — trop long"
    assert_not @prospect.enriching?
  end
end
