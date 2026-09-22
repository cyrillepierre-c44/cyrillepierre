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

    # `studio-btn-danger` n'est qu'un modificateur de couleur : sans la classe de base, le bouton
    # sort sans forme ni marges, au milieu de deux boutons correctement dessinés.
    test "the delete button is drawn like the other buttons of the page" do
      sign_in @admin

      get studio_prospect_path(@prospect)

      assert_select "form[action=?] .btn-cp-outline.studio-btn-danger", studio_prospect_path(@prospect)
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

    # La note de diagnostic part du même brief que la proposition : le pont est sur la fiche.
    test "show offers to draft an executive brief from the prospect sheet" do
      sign_in @admin

      get studio_prospect_path(@prospect)

      assert_response :success
      assert_select "a[href=?]", new_studio_generation_path(kind: "executive_brief", prospect_id: @prospect.id),
                    text: /note de diagnostic/
      assert_select "a[href=?]", new_studio_generation_path(kind: "commercial_proposal", prospect_id: @prospect.id),
                    text: /proposition/
    end
  
    test "the sheet offers the first message before the note and the proposal" do
      sign_in @admin

      get studio_prospect_path(@prospect)

      links = css_select(".studio-show-toolbar a.btn-cp-primary, .studio-show-toolbar a.btn-cp-outline").map(&:text)
      assert_equal ["Modifier", "Rédiger un premier message", "Rédiger une proposition", "Rédiger une note de diagnostic"],
                   links.first(4)
      assert_select "a[href=?]", new_studio_generation_path(kind: "outreach_message", prospect_id: @prospect.id)
    end
  
    test "asking for the public information enqueues the enrichment and the sheet says it is running" do
      sign_in @admin

      assert_enqueued_with(job: ProspectEnrichmentJob, args: [@prospect]) do
        patch enrich_studio_prospect_path(@prospect)
      end

      assert_redirected_to studio_prospect_path(@prospect)
      assert @prospect.reload.enriching?
      follow_redirect!
      assert_select "#renseignements .studio-empty", text: /Recherche en cours/
      assert_select "#renseignements form button[disabled]"
    end

    test "the sheet shows the public information and hands it to the brief" do
      @prospect.update!(enrichment: "IDENTITÉ : Fonderie Sud · SIREN 111", enriched_at: Time.zone.local(2026, 9, 22, 12, 0))
      sign_in @admin

      get studio_prospect_path(@prospect)

      assert_select "#renseignements pre.studio-output", text: /SIREN 111/
      assert_select "#renseignements form button", text: "Actualiser"
      assert_includes @prospect.brief_for_proposal, "Renseignements publics (annuaire, BODACC, presse — au 22/09/2026) :\nIDENTITÉ : Fonderie Sud"
    end

    test "an editor cannot enrich someone else's sheet" do
      sign_in @editor

      patch enrich_studio_prospect_path(@prospect)

      assert_response :not_found
      assert_nil @prospect.reload.enrichment_requested_at
    end
  
    test "asking for the decision maker enqueues the web search and the sheet shows the names with their sources" do
      sign_in @admin

      assert_enqueued_with(job: DecisionMakerSearchJob, args: [@prospect]) do
        patch find_contacts_studio_prospect_path(@prospect)
      end
      assert_redirected_to studio_prospect_path(@prospect)
      follow_redirect!
      assert_select "#decideur .studio-empty", text: /Recherche en cours/
      assert_select "#decideur form button[disabled]"

      @prospect.update!(contacts_research: "- Jean Martin — directeur de l'usine — https://example.com/a",
                        contacts_researched_at: Time.current, name: "Jean Martin")
      get studio_prospect_path(@prospect)
      assert_select "#decideur pre.studio-output", text: /Jean Martin/
      assert_select "#decideur form button", text: "Chercher à nouveau"
      assert_includes @prospect.brief_for_proposal, "Interlocuteur : Jean Martin"
      assert_includes @prospect.brief_for_proposal, "Recherche du décideur (web, à confirmer) :\n- Jean Martin"
    end

    test "the placeholder name is not handed to the brief as a contact" do
      @prospect.update!(name: Prospect::PLACEHOLDER_NAME)

      assert_not_includes @prospect.brief_for_proposal, "Interlocuteur"
    end
  end
end
