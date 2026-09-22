require "test_helper"

class OutreachMailerTest < ActionMailer::TestCase
  setup do
    user = User.create!(email: "outreach-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
    @prospect = Prospect.create!(user: user, name: "Marie Durand", company: "MAPEI — Saint-Vulbas",
                                 email: "marie.durand@example.com", source: :veille, status: :a_contacter)
    @generation = Generation.create!(
      user: user, prospect: @prospect, kind: :outreach_message, status: :generated,
      output: "###VERSION_FINALE###\nBonjour Marie, j'ai vu votre annonce sur Indeed du 9 septembre…\n\n" \
              "###A_PERSONNALISER###\n- Le prénom.\n\n###VERSION_COURTE###\nObjet : Votre poste de directeur d'unité " \
              "sur Indeed\nBonjour Marie,\n\nJ'ai vu votre annonce sur Indeed du 9 septembre.\n\nCyrille PIERRE"
    )
  end

  test "the first contact leaves from contact@ as plain text, with subject, body and the opt-out footer" do
    mail = OutreachMailer.first_contact(@generation)

    assert_equal ["marie.durand@example.com"], mail.to
    assert_equal [SiteIdentity::EMAIL], mail.from
    assert_equal [SiteIdentity::EMAIL], mail.reply_to
    assert_equal "Votre poste de directeur d'unité sur Indeed", mail.subject
    assert_equal "text/plain", mail.mime_type
    body = mail.body.encoded
    assert_includes body, "Bonjour Marie,\n\nJ'ai vu votre annonce sur Indeed du 9 septembre."
    assert_not_includes body, "Objet :"
    assert_includes body, "répondez simplement « stop »"
    assert_includes body, SiteIdentity::HOST
  end
end
