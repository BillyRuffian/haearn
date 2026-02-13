# frozen_string_literal: true

class ProgressPhotoPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    record.user_id == user.id
  end

  def create?
    true
  end

  def destroy?
    record.user_id == user.id
  end

  def compare?
    true
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user_id: user.id)
    end
  end
end
