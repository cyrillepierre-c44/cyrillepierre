require "test_helper"

class ApplicationPolicyTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "policy-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @policy = ApplicationPolicy.new(@user, Object.new)
  end

  # La politique de base refuse tout : une policy dérivée doit ouvrir explicitement chaque
  # action, jamais l'inverse.
  test "denies every action by default" do
    assert_not @policy.index?
    assert_not @policy.show?
    assert_not @policy.create?
    assert_not @policy.new?
    assert_not @policy.update?
    assert_not @policy.edit?
    assert_not @policy.destroy?
  end

  test "new? follows create? and edit? follows update?" do
    permissive = Class.new(ApplicationPolicy) do
      def create? = true
      def update? = true
    end.new(@user, Object.new)

    assert permissive.new?
    assert permissive.edit?
  end

  test "exposes the user and the record it was built with" do
    record = Object.new
    policy = ApplicationPolicy.new(@user, record)

    assert_equal @user, policy.user
    assert_same record, policy.record
  end

  test "the base scope refuses to resolve without a subclass" do
    scope = ApplicationPolicy::Scope.new(@user, Generation.all)

    assert_raises(NoMethodError) { scope.resolve }
  end
end
