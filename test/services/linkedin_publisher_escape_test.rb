require "test_helper"

# LinkedIn accepte la requête, publie le post, et jette TOUT ce qui suit un caractère réservé non
# échappé. Aucune erreur, aucun code HTTP anormal : un post publié le 15/09/2026 s'est retrouvé
# coupé net sur une parenthèse ouvrante, juste avant son lien et sa question finale.
class LinkedinPublisherEscapeTest < ActiveSupport::TestCase
  def escape(text)
    LinkedinPublisher.new(Generation.new).send(:escape_little_text, text)
  end

  test "the character that truncated a real post is escaped" do
    assert_equal "Le reste \\(volontariat, ECRS\\) est ici", escape("Le reste (volontariat, ECRS) est ici")
  end

  test "every reserved character is escaped" do
    LinkedinPublisher::LITTLE_TEXT_RESERVED.each do |char|
      assert_equal "a\\#{char}b", escape("a#{char}b"), "#{char} devrait être échappé"
    end
  end

  # Piège de gsub : dans une chaîne de remplacement, « \\ » est interprété, et la barre oblique
  # disparaissait au lieu d'être doublée.
  test "a literal backslash is doubled, never swallowed" do
    assert_equal "a\\\\b", escape("a\\b")
  end

  test "an escape is never escaped twice" do
    assert_equal "\\(x\\)", escape("(x)")
  end

  # Échappé, un hashtag deviendrait du texte ordinaire et perdrait son lien.
  test "hashtags are deliberately left alone" do
    assert_equal "#DialogueSocial", escape("#DialogueSocial")
  end

  test "ordinary text, accents and URLs pass through untouched" do
    text = "Réduire de 10 % les rebuts : https://www.cyrillepierre.com/actus/167 — c'est faisable."
    assert_equal text, escape(text)
  end

  test "the published body carries the escaped text, not the raw one" do
    user = User.create!(email: "escape@example.com", password: "password123")
    generation = Generation.create!(user: user, kind: :linkedin_post,
                                    output: "Un point **clé** (et une parenthèse).")

    commentary = LinkedinPublisher.new(generation).send(:post_body, nil)[:commentary]

    assert_includes commentary, "\\(et une parenthèse\\)"
    assert_not_includes commentary, "**"
  end
end
