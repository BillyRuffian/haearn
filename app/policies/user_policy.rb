class UserPolicy < ApplicationPolicy
  def index?
    user.admin?
  end

  def show?
    user.admin? || record == user
  end

  def edit?
    user.admin? || record == user
  end

  def update?
    user.admin? || record == user
  end

  def toggle_admin?
    user.admin? && record != user
  end

  def deactivate?
    user.admin? && record != user
  end

  def reactivate?
    user.admin?
  end

  def impersonate?
    user.admin? && record != user && record.active?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(id: user.id)
      end
    end
  end
end
