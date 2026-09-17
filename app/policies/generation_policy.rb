class GenerationPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    owner_or_admin?
  end

  def create?
    true
  end

  def update?
    owner_or_admin?
  end

  def destroy?
    owner_or_admin?
  end

  def regenerate?
    update?
  end

  def document?
    show?
  end

  def pdf?
    show?
  end

  def generate_visual?
    update?
  end

  def publish_to_linkedin?
    update?
  end

  def publish?
    admin? && record.publishable?
  end

  def unpublish?
    admin? && record.publishable?
  end

  Scope = ApplicationPolicy::OwnedScope
end
