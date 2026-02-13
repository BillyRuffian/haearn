class ExercisePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    user.admin? || record.global? || record.user_id == user.id
  end

  def create?
    true
  end

  def update?
    user.admin? || record.user_id == user.id
  end

  def destroy?
    user.admin? || record.user_id == user.id
  end

  def promote?
    user.admin? && !record.global?
  end

  def review?
    user.admin?
  end

  def merge?
    user.admin?
  end

  def perform_merge?
    user.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.for_user(user)
      end
    end
  end
end
