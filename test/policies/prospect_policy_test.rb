require "test_helper"

class ProspectPolicyTest < ActiveSupport::TestCase
  setup do
    @editor = User.create!(email: "prospect-editor@example.com", password: "password123", role: :editor)
    @other = User.create!(email: "prospect-other@example.com", password: "password123", role: :editor)
    @admin = User.create!(email: "prospect-admin@example.com", password: "password123", role: :admin)
    @own = Prospect.create!(user: @editor, name: "Piste perso")
    @from_site = Prospect.create!(name: "Piste du site", source: :site_contact)
  end

  test "an editor manages his own prospects only" do
    policy = ProspectPolicy.new(@editor, @own)

    assert policy.index?
    assert policy.show?
    assert policy.update?
    assert policy.destroy?
    assert_not ProspectPolicy.new(@other, @own).show?
  end

  test "an editor cannot open a prospect coming from the site" do
    assert_not ProspectPolicy.new(@editor, @from_site).show?
  end

  test "an admin manages every prospect" do
    assert ProspectPolicy.new(@admin, @from_site).show?
    assert ProspectPolicy.new(@admin, @own).destroy?
  end

  test "the scope hides the other prospects from an editor" do
    assert_equal [@own.id], ProspectPolicy::Scope.new(@editor, Prospect).resolve.pluck(:id)
  end

  test "the scope shows everything to an admin" do
    assert_equal [@own.id, @from_site.id].sort, ProspectPolicy::Scope.new(@admin, Prospect).resolve.pluck(:id).sort
  end
end
