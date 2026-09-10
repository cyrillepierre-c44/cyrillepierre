require "test_helper"

class ArticleFormatterTest < ActiveSupport::TestCase
  test "renders the restricted markdown the article prompt asks for" do
    html = ArticleFormatter.call(<<~MD)
      Un premier paragraphe d'introduction.

      ## Pourquoi le TRS ment

      Une explication **essentielle** ici.
      Et une deuxième ligne du même paragraphe.

      ### Un sous-point

      - premier point
      - second point

      1. première étape
      2. seconde étape
    MD

    # L'apostrophe ressort échappée : c'est le prix de l'échappement systématique du texte
    # du modèle, et le navigateur l'affiche à l'identique.
    assert_includes html, "<p>Un premier paragraphe d&#39;introduction.</p>"
    assert_includes html, "<h2>Pourquoi le TRS ment</h2>"
    assert_includes html, "<h3>Un sous-point</h3>"
    assert_includes html, "<strong>essentielle</strong>"
    assert_includes html, "Une explication <strong>essentielle</strong> ici.<br>Et une deuxième ligne"
    assert_includes html, "<ul><li>premier point</li><li>second point</li></ul>"
    assert_includes html, "<ol><li>première étape</li><li>seconde étape</li></ol>"
  end

  test "the output is marked safe so the view renders the tags" do
    assert_predicate ArticleFormatter.call("Bonjour"), :html_safe?
  end

  # Le texte vient d'un LLM : aucune balise venue du modèle ne doit atteindre la page.
  test "html coming from the model is escaped, never executed" do
    html = ArticleFormatter.call("Avant <script>alert('x')</script> après")

    assert_includes html, "&lt;script&gt;"
    assert_not_includes html, "<script>"
  end

  test "a heading that also contains bold keeps both" do
    assert_includes ArticleFormatter.call("## Le **vrai** sujet"), "<h2>Le <strong>vrai</strong> sujet</h2>"
  end

  test "a list mixing bullets and prose stays a paragraph" do
    html = ArticleFormatter.call("- un point\net une phrase libre")

    assert_includes html, "<p>"
    assert_not_includes html, "<ul>"
  end

  test "blank input produces nothing" do
    assert_equal "", ArticleFormatter.call(nil)
    assert_equal "", ArticleFormatter.call("   \n\n  ")
  end

  test "plain_text strips the markup for excerpts and meta descriptions" do
    plain = ArticleFormatter.plain_text("## Un titre\n\nUn texte **en gras**.\n\n- un point\n* un autre")

    assert_equal "Un titre Un texte en gras. un point un autre", plain
  end

  test "plain_text tolerates a missing output" do
    assert_equal "", ArticleFormatter.plain_text(nil)
  end
end
