class MachinePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    user.admin? || record.gym.user_id == user.id
  end

  def create?
    true
  end

  def update?
    record.gym.user_id == user.id
  end

  def destroy?
    record.gym.user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.joins(:gym).where(gyms: { user_id: user.id })
      end
    end
  end
end
