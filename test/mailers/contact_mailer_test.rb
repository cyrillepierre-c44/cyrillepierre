require "test_helper"

class ContactMailerTest < ActionMailer::TestCase
  def new_contact(**overrides)
    ContactMailer.new_contact(**{
      name: "Jean Dupont", email: "jean@example.com", company: "Une Usine SA",
      phone: "0600000000", themes: [ "Excellence opérationnelle", "Tech & IA" ],
      summary: "🎯 **Enjeu :** structurer l'atelier.", history: nil,
      precision: nil, sector: "agroalimentaire", size: "~200 personnes"
    }.merge(overrides))
  end

  test "the notification goes to Cyrille and replies to the prospect" do
    mail = new_contact

    assert_equal [ "cyrille.pierre@gmail.com" ], mail.to
    assert_equal [ "jean@example.com" ], mail.reply_to
  end

  # Le sujet portait cyrillepierre.fr, un domaine qui n'est pas celui du site.
  test "the subject carries the right domain and the selected themes" do
    mail = new_contact

    assert_includes mail.subject, "[cyrillepierre.com]"
    assert_includes mail.subject, "Excellence opérationnelle"
    assert_includes mail.subject, "Jean Dupont"
  end

  test "the notification body carries the collected context" do
    body = new_contact.body.encoded

    assert_includes body, "Jean Dupont"
    assert_includes body, "Une Usine SA"
    assert_includes body, "agroalimentaire"
    assert_includes body, "cyrillepierre.com"
    assert_not_includes body, "cyrillepierre.fr"
  end

  test "the conversation history is parsed and rendered" do
    history = [ { role: "assistant", content: "Quel est votre défi ?" },
               { role: "user", content: "Réduire les arrêts machine." } ].to_json

    body = new_contact(history: history).body.encoded

    assert_includes body, "Réduire les arrêts machine."
  end

  # Le champ arrive du navigateur : un JSON cassé ne doit pas empêcher l'email de partir.
  test "a malformed history does not break the email" do
    mail = new_contact(history: "{ceci n'est pas du JSON")

    assert_nothing_raised { mail.body.encoded }
    assert_includes mail.body.encoded, "Jean Dupont"
  end

  test "an empty history is handled" do
    assert_nothing_raised { new_contact(history: nil).body.encoded }
    assert_nothing_raised { new_contact(history: "").body.encoded }
  end

  test "the client confirmation goes to the prospect" do
    mail = ContactMailer.confirmation_to_client(
      name: "Jean Dupont", email: "jean@example.com",
      themes: [ "Excellence opérationnelle" ], summary: "Résumé."
    )

    assert_equal [ "jean@example.com" ], mail.to
    assert_includes mail.subject, "Cyrille PIERRE"
    body = mail.body.encoded
    assert_includes body, "Jean Dupont"
    assert_includes body, "cyrillepierre.com"
    assert_not_includes body, "cyrillepierre.fr"
  end
end
