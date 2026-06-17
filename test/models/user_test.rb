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
end
