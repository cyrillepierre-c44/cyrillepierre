# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end

  # Le cas de tous les enregistrements du Studio : un admin voit tout, un éditeur ne voit que
  # ce qu'il a créé. Une policy l'adopte avec `Scope = ApplicationPolicy::OwnedScope`.
  class OwnedScope < Scope
    def resolve
      user.admin? ? scope.all : scope.where(user: user)
    end
  end

  private

  def admin?
    user.admin?
  end

  def owner_or_admin?
    admin? || record.user_id == user.id
  end
end
