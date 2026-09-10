require "test_helper"

# La purge n'est pas appelée depuis le code applicatif : elle ne tourne que si
# config/recurring.yml la déclare. Renommer le job sans toucher au YAML casserait
# silencieusement la durée de conservation annoncée sur /politique-de-confidentialite.
class RecurringScheduleTest < ActiveSupport::TestCase
  setup do
    @schedule = YAML.load_file(Rails.root.join("config/recurring.yml")).fetch("production")
  end

  test "the prospect purge is scheduled in production" do
    task = @schedule.fetch("purge_expired_prospects")

    assert_equal "ProspectPurgeJob", task["class"]
    assert task["schedule"].present?
  end

  test "every scheduled job class actually exists" do
    @schedule.each_value do |task|
      next if task["class"].blank?

      assert_nothing_raised { task["class"].constantize }
    end
  end
end
