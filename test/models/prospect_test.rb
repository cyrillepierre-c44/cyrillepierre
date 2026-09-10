require "test_helper"

class ProspectTest < ActiveSupport::TestCase
  test "record_contact_request stores what the assistant collected" do
    prospect = Prospect.record_contact_request(
      name: "Marie Durand", email: "marie@example.com", company: "Fonderie Sud",
      phone: "0600000000", sector: "métallurgie", size: "~120 personnes",
      themes: ["Excellence opérationnelle", "Tech & IA"],
      summary: "TRS en baisse.", conversation: "Visiteur : bonjour", precision: "Urgent."
    )

    assert prospect.persisted?
    assert prospect.nouveau?
    assert prospect.source_site_contact?
    assert_equal "~120 personnes", prospect.company_size
    assert_equal ["Excellence opérationnelle", "Tech & IA"], prospect.themes
    assert_equal "Urgent.", prospect.visitor_precision
    assert_not_nil prospect.last_contact_at
  end

  test "record_contact_request falls back to the email when the name is missing" do
    prospect = Prospect.record_contact_request(name: nil, email: "sans-nom@example.com")

    assert_equal "sans-nom@example.com", prospect.name
  end

  test "record_contact_request falls back to a placeholder without name nor email" do
    prospect = Prospect.record_contact_request(name: nil, email: nil, company: nil)

    assert_equal "Contact sans nom", prospect.name
  end

  test "themes_text reads and writes the array" do
    prospect = Prospect.new(name: "Test", themes_text: " performance ,  digitalisation , ")

    assert_equal %w[performance digitalisation], prospect.themes
    assert_equal "performance, digitalisation", prospect.themes_text
  end

  test "normalize_themes drops the blanks left by the form" do
    prospect = Prospect.create!(name: "Test", themes: ["  performance ", "", nil])

    assert_equal ["performance"], prospect.themes
  end

  test "relance_due? only fires on an open prospect whose date has come" do
    due = Prospect.new(name: "A", status: :en_discussion, next_action_on: Date.current)
    future = Prospect.new(name: "B", status: :en_discussion, next_action_on: Date.current + 1)
    closed = Prospect.new(name: "C", status: :gagne, next_action_on: Date.current - 1)

    assert due.relance_due?
    assert_not future.relance_due?
    assert_not closed.relance_due?
  end

  test "ouverts and en_retard select the prospects still to work on" do
    late = Prospect.create!(name: "En retard", status: :a_contacter, next_action_on: Date.current - 2)
    Prospect.create!(name: "Plus tard", status: :a_contacter, next_action_on: Date.current + 5)
    Prospect.create!(name: "Gagné", status: :gagne, next_action_on: Date.current - 2)

    assert_equal [late.id], Prospect.ouverts.en_retard.pluck(:id)
  end

  test "brief_for_proposal assembles the qualified need" do
    prospect = Prospect.new(name: "Marie", company: "Fonderie Sud", sector: "métallurgie",
                            company_size: "~120 personnes", themes: %w[performance],
                            summary: "TRS en baisse.", notes: "Vu au salon.")

    brief = prospect.brief_for_proposal

    assert_includes brief, "Client : Fonderie Sud"
    assert_includes brief, "Secteur : métallurgie"
    assert_includes brief, "Thèmes : performance"
    assert_includes brief, "TRS en baisse."
    assert_includes brief, "Vu au salon."
  end

  test "brief_for_proposal stays empty without any qualified data" do
    assert_equal "", Prospect.new(name: "Inconnu").brief_for_proposal
  end

  test "display_company falls back to a dash" do
    assert_equal "—", Prospect.new(name: "Sans société").display_company
  end

  test "labels expose the human wording" do
    prospect = Prospect.new(name: "X", status: :proposition, source: :soce)

    assert_equal "Proposition envoyée", prospect.status_label
    assert_equal "Soce (Arts et Métiers)", prospect.source_label
  end

  test "name is required" do
    assert_not Prospect.new.valid?
  end
end
