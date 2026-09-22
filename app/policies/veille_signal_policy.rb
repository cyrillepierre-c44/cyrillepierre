# Les signaux n'appartiennent à personne : c'est la veille de Cyrille, donc des admins. Un
# éditeur ne voit rien et ne tranche rien.
class VeilleSignalPolicy < ApplicationPolicy
  def index?
    user.admin?
  end

  def keep?
    user.admin?
  end

  def dismiss?
    user.admin?
  end

  class Scope < Scope
    def resolve
      user.admin? ? scope.all : scope.none
    end
  end
end
