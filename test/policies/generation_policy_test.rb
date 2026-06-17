require "test_helper"

class GenerationPolicyTest < ActiveSupport::TestCase
  setup do
    @editor = User.create!(email: "editor@example.com", password: "password123", role: :editor)
    @other_editor = User.create!(email: "other@example.com", password: "password123", role: :editor)
    @admin = User.create!(email: "admin@example.com", password: "password123", role: :admin)
    @own_generation = Generation.create!(user: @editor, kind: :linkedin_post)
    @site_actu = Generation.create!(user: @editor, kind: :site_actu)
  end

  test "editor can manage their own generation" do
    policy = GenerationPolicy.new(@editor, @own_generation)
    assert policy.show?
    assert policy.update?
    assert policy.destroy?
  end

  test "editor cannot manage another editor's generation" do
    policy = GenerationPolicy.new(@other_editor, @own_generation)
    assert_not policy.show?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "admin can manage any generation" do
    policy = GenerationPolicy.new(@admin, @own_generation)
    assert policy.show?
    assert policy.update?
    assert policy.destroy?
  end

  test "only admin can publish a site_actu" do
    assert GenerationPolicy.new(@admin, @site_actu).publish?
    assert_not GenerationPolicy.new(@editor, @site_actu).publish?
  end

  test "non-site_actu generations are never publishable" do
    assert_not GenerationPolicy.new(@admin, @own_generation).publish?
  end

  test "scope restricts editors to their own generations" do
    scope = GenerationPolicy::Scope.new(@editor, Generation.all).resolve
    assert_includes scope, @own_generation
    assert_includes scope, @site_actu

    scope_other = GenerationPolicy::Scope.new(@other_editor, Generation.all).resolve
    assert_not_includes scope_other, @own_generation
    assert_not_includes scope_other, @site_actu
  end

  test "scope returns everything for admin" do
    scope = GenerationPolicy::Scope.new(@admin, Generation.all).resolve
    assert_includes scope, @own_generation
    assert_includes scope, @site_actu
  end
end
