require "test_helper"

class DecisionMakerSearchJobTest < ActiveJob::TestCase
  setup do
    user = User.create!(email: "dmjob-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @prospect = Prospect.create!(user: user, name: "X", company: "Aldes", contacts_requested_at: Time.current)
  end

  test "writes the result and the date, and a failure in place" do
    DecisionMakerFinder.stub(:call, "DÉCIDEURS PROBABLES : …") { DecisionMakerSearchJob.perform_now(@prospect) }
    assert_equal "DÉCIDEURS PROBABLES : …", @prospect.reload.contacts_research
    assert @prospect.contacts_researched?
    assert_not @prospect.contacts_searching?

    @prospect.update!(contacts_requested_at: Time.current + 1)
    DecisionMakerFinder.stub(:call, ->(_) { raise Tavily::NotConfiguredError, "TAVILY_API_KEY absente" }) do
      DecisionMakerSearchJob.perform_now(@prospect)
    end
    assert_includes @prospect.reload.contacts_research, "Recherche impossible : Tavily::NotConfiguredError — TAVILY_API_KEY absente"
  end
end
