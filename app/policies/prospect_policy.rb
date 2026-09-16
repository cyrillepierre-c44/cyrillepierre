class ProspectPolicy < ApplicationPolicy
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

  # Les prospects venus du formulaire du site n'appartiennent à personne : seuls les admins
  # les voient, un éditeur ne voit que ses propres saisies.
  Scope = ApplicationPolicy::OwnedScope
end
