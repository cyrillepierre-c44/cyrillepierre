require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  def user_expiring_in(duration)
    User.new(linkedin_token_expires_at: duration&.from_now)
  end

  # Toutes les échéances ci-dessous sont relatives à maintenant, et `linkedin_days_remaining`
  # compare des DATES, pas des instants. Sans horloge figée, « dans 2 heures » bascule au
  # lendemain dès 22 h à Paris et le compte passe de 0 à 1 : la suite échouait donc chaque soir,
  # en local comme en CI. Midi met tous les calculs loin des deux bornes de la journée.
  setup { travel_to Time.zone.local(2026, 6, 15, 12, 0, 0) }

  test "spells out the number of days left" do
    assert_equal "expire dans 60 jours", linkedin_expiry_label(user_expiring_in(60.days))
  end

  test "says tomorrow rather than in 1 days" do
    assert_equal "expire demain", linkedin_expiry_label(user_expiring_in(1.day))
  end

  test "says today on the last day" do
    assert_equal "expire aujourd'hui", linkedin_expiry_label(user_expiring_in(2.hours))
  end

  # Le badge n'est affiché que pour un compte connecté, mais l'helper ne doit pas exploser
  # si la date manque.
  test "returns nothing without an expiry date" do
    assert_nil linkedin_expiry_label(User.new)
  end

  test "colours the badge red on the last two days" do
    assert_equal "studio-badge--danger", linkedin_expiry_badge_modifier(user_expiring_in(2.hours))
    assert_equal "studio-badge--danger", linkedin_expiry_badge_modifier(user_expiring_in(1.day))
  end

  test "colours the badge amber within two weeks of the expiry" do
    assert_equal "studio-badge--warning", linkedin_expiry_badge_modifier(user_expiring_in(10.days))
  end

  test "leaves the badge neutral when the expiry is far away" do
    assert_nil linkedin_expiry_badge_modifier(user_expiring_in(60.days))
  end
end
