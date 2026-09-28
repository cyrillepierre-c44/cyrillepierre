# La mémoire de tri est celle de Cyrille : les admins la lisent et la corrigent, un éditeur ne la
# voit pas — même règle que les signaux.
class VeilleDecisionPolicy < ApplicationPolicy
  def update?
    user.admin?
  end

  class Scope < Scope
    def resolve
      user.admin? ? scope.all : scope.none
    end
  end
end
