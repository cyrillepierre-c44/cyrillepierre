require "test_helper"

module Studio
  class ProspectsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = User.create!(email: "pipeline-admin@example.com", password: "password123", role: :admin)
      @editor = User.create!(email: "pipeline-editor@example.com", password: "password123", role: :editor)
      @prospect = Prospect.create!(user: @admin, name: "Fonderie Sud", company: "Fonderie Sud",
                                   status: :en_discussion, source: :reseau)
    end

    test "the pipeline requires a signed in user" do
      get studio_prospects_path

      assert_redirected_to new_user_session_path
    end

    test "index lists the prospects and the overdue follow-ups" do
      Prospect.create!(user: @admin, name: "À relancer", status: :a_contacter,
                       next_action_on: Date.current - 1, next_action: "Rappeler")
      sign_in @admin

      get studio_prospects_path

      assert_response :success
      assert_select ".studio-list-item", minimum: 2
      assert_select ".prospect-relances", 1
    end

    test "index filters on a status" do
      sign_in @admin

      get studio_prospects_path(status: "gagne")

      assert_response :success
      assert_select ".studio-list-item", 0
    end

    test "index ignores an unknown status instead of blowing up" do
      sign_in @admin

      get studio_prospects_path(status: "n-importe-quoi")

      assert_response :success
      assert_select ".studio-list-item", 1
    end

    test "show displays the qualified need and the follow-up form" do
      @prospect.update!(summary: "TRS en baisse.", visitor_precision: "Urgent.",
                        conversation: "Visiteur : bonjour", notes: "Vu au salon.")
      sign_in @admin

      get studio_prospect_path(@prospect)

      assert_response :success
      assert_select "h1", text: "Fonderie Sud"
      assert_select "form[action=?]", studio_prospect_path(@prospect)
    end

    test "an editor cannot open a prospect coming from the site" do
      site_lead = Prospect.create!(name: "Piste du site", source: :site_contact)
      sign_in @editor

      get studio_prospect_path(site_lead)

      assert_response :not_found
    end

    test "new renders the manual creation form" do
      sign_in @admin

      get new_studio_prospect_path

      assert_response :success
    end

    test "create records a network contact for the signed in user" do
      sign_in @admin

      assert_difference("Prospect.count", 1) do
        post studio_prospects_path, params: { prospect: { name: "Jean Martin", company: "Soce",
                                                          source: "soce", status: "a_contacter",
                                                          themes_text: "performance, digitalisation" } }
      end

      created = Prospect.order(:created_at).last
      assert_redirected_to studio_prospect_path(created)
      assert_equal @admin, created.user
      assert_equal %w[performance digitalisation], created.themes
    end

    test "create re-renders the form when the name is missing" do
      sign_in @admin

      assert_no_difference("Prospect.count") do
        post studio_prospects_path, params: { prospect: { name: "" } }
      end

      assert_response :unprocessable_entity
    end

    test "edit renders the edition form" do
      sign_in @admin

      get edit_studio_prospect_path(@prospect)

      assert_response :success
    end

    test "update saves the next action" do
      sign_in @admin

      patch studio_prospect_path(@prospect), params: { prospect: { status: "proposition",
                                                                   next_action: "Envoyer la proposition",
                                                                   next_action_on: "2026-09-20" } }

      assert_redirected_to studio_prospect_path(@prospect)
      @prospect.reload
      assert_equal "proposition", @prospect.status
      assert_equal Date.new(2026, 9, 20), @prospect.next_action_on
    end

    test "update records the day of the last exchange" do
      sign_in @admin

      patch studio_prospect_path(@prospect), params: { prospect: { last_contact_at: "2026-09-01" } }

      assert_equal Date.new(2026, 9, 1), @prospect.reload.last_contact_at.to_date
    end

    test "show offers the last contact field the retention window relies on" do
      sign_in @admin

      get studio_prospect_path(@prospect)

      assert_select "input[name=?]", "prospect[last_contact_at]"
    end

    test "update re-renders the form when the record is invalid" do
      sign_in @admin

      patch studio_prospect_path(@prospect), params: { prospect: { name: "" } }

      assert_response :unprocessable_entity
    end

    test "destroy removes the prospect and goes back to the pipeline" do
      sign_in @admin

      assert_difference("Prospect.count", -1) do
        delete studio_prospect_path(@prospect)
      end

      assert_redirected_to studio_prospects_path
    end
  end
end
