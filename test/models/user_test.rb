require "test_helper"

class UserTest < ActiveSupport::TestCase
  def build_user(attrs = {})
    User.new({ email: "user@example.com", password: "password123" }.merge(attrs))
  end

  test "defaults to the editor role" do
    user = build_user
    assert user.editor?
  end

  test "can be promoted to admin" do
    user = build_user(role: :admin)
    assert user.admin?
  end

  test "requires an email" do
    user = build_user(email: nil)
    assert_not user.valid?
  end

  test "requires a unique email" do
    build_user.save!
    duplicate = build_user
    assert_not duplicate.valid?
  end

  test "is not linkedin_connected? without a token" do
    assert_not build_user.linkedin_connected?
  end

  test "is not linkedin_connected? when the token has expired" do
    user = build_user(linkedin_access_token: "token", linkedin_token_expires_at: 1.day.ago)
    assert_not user.linkedin_connected?
  end

  test "is linkedin_connected? with a valid, unexpired token" do
    user = build_user(linkedin_access_token: "token", linkedin_token_expires_at: 60.days.from_now)
    assert user.linkedin_connected?
  end

  test "encrypts the linkedin_access_token at rest" do
    user = build_user(linkedin_access_token: "super-secret-token")
    user.save!

    raw = ActiveRecord::Base.connection.select_value(
      "SELECT linkedin_access_token FROM users WHERE id = #{user.id}"
    )
    assert_not_includes raw, "super-secret-token"
    assert_equal "super-secret-token", user.reload.linkedin_access_token
  end
end
