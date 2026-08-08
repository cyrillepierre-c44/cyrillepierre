require "test_helper"

class LinkedinTextFormatterTest < ActiveSupport::TestCase
  test "leaves text without markdown untouched" do
    assert_equal "Un post tout simple.", LinkedinTextFormatter.call("Un post tout simple.")
  end

  test "turns **bold** into Unicode bold letters" do
    assert_equal "𝗧𝗥𝗦", LinkedinTextFormatter.call("**TRS**")
  end

  test "bolds digits as well as letters" do
    assert_equal "𝟲𝟳", LinkedinTextFormatter.call("**67**")
  end

  test "only the marked segments are converted" do
    result = LinkedinTextFormatter.call("Le **TRS** est passé à 67%.")

    assert_includes result, "𝗧𝗥𝗦"
    assert_includes result, "Le "
    assert_includes result, " est passé à 67%."
  end

  # Le bloc Unicode gras ne définit ni "é" ni "%". Les accents passent par une décomposition
  # NFD (base + accent) ; les symboles restent tels quels, faute d'équivalent — limite connue.
  test "accented letters keep their accent over a bolded base letter" do
    result = LinkedinTextFormatter.call("**équipe**")

    # "é" ressort en deux points de code : le "e" gras suivi de l'accent aigu combinant, faute
    # de caractère gras accentué précomposé dans Unicode. Le rendu reste un é gras.
    assert_equal [ 0x1D5F2, 0x0301, 0x1D5FE, 0x1D602, 0x1D5F6, 0x1D5FD, 0x1D5F2 ], result.unpack("U*")
  end

  test "symbols with no bold equivalent are left as they are" do
    assert_equal "%", LinkedinTextFormatter.call("**%**")
    assert_equal "+/-", LinkedinTextFormatter.call("**+/-**")
  end

  test "handles several bold segments in the same text" do
    result = LinkedinTextFormatter.call("**Avant** puis **Apres**")

    assert_includes result, "𝗔𝘃𝗮𝗻𝘁"
    assert_includes result, "𝗔𝗽𝗿𝗲𝘀"
    assert_includes result, " puis "
  end

  test "tolerates nil" do
    assert_equal "", LinkedinTextFormatter.call(nil)
  end
end
