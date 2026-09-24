require "test_helper"
require "rake"

class ProspectsCabinetsTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task["prospects:cabinets"].reenable
    @admin = User.create!(email: "cabinets-admin@example.com", password: "password123", role: :admin)
  end

  test "creates one fiche per cabinet, one per working day, and never twice" do
    travel_to Time.zone.local(2026, 9, 24, 12) do
      assert_difference("Prospect.source_cabinet.count", CabinetReferencing::CABINETS.size) do
        capture_io { Rake::Task["prospects:cabinets"].invoke }
      end

      first = Prospect.source_cabinet.order(:next_action_on).first
      assert first.a_contacter?
      assert_equal Date.new(2026, 9, 25), first.next_action_on
      assert_includes first.next_action, "https://aptimen-managers.com/espace-managers/"
      assert_equal Prospect::PLACEHOLDER_NAME, first.name
      assert_equal @admin, first.user
      weekend = Prospect.source_cabinet.select { |p| p.next_action_on.saturday? || p.next_action_on.sunday? }
      assert_empty weekend

      Rake::Task["prospects:cabinets"].reenable
      assert_no_difference("Prospect.count") do
        capture_io { Rake::Task["prospects:cabinets"].invoke }
      end
    end
  end

  test "the task aborts without an administrator" do
    User.delete_all

    assert_raises(SystemExit) { capture_io { Rake::Task["prospects:cabinets"].invoke } }
  end
end
