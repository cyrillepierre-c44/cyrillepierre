require "test_helper"

class ProspectPurgeJobTest < ActiveSupport::TestCase
  test "removes the prospects past the announced retention period" do
    old = Prospect.create!(name: "Ancien", last_contact_at: Prospect::RETENTION.ago - 1.day)
    recent = Prospect.create!(name: "Récent", last_contact_at: Prospect::RETENTION.ago + 1.day)

    assert_difference("Prospect.count", -1) do
      ProspectPurgeJob.perform_now
    end

    assert_not Prospect.exists?(old.id)
    assert Prospect.exists?(recent.id)
  end

  test "falls back on the creation date when no contact was ever logged" do
    never_worked = Prospect.create!(name: "Jamais travaillé", last_contact_at: nil)
    never_worked.update_column(:created_at, Prospect::RETENTION.ago - 1.day)

    ProspectPurgeJob.perform_now

    assert_not Prospect.exists?(never_worked.id)
  end

  test "a freshly created prospect survives" do
    Prospect.create!(name: "Tout neuf")

    assert_no_difference("Prospect.count") do
      ProspectPurgeJob.perform_now
    end
  end

  test "does nothing and reports zero when there is nothing to purge" do
    assert_equal 0, ProspectPurgeJob.perform_now
  end

  test "reports how many prospects it removed" do
    Prospect.create!(name: "Ancien", last_contact_at: Prospect::RETENTION.ago - 1.day)

    assert_equal 1, ProspectPurgeJob.perform_now
  end
end
