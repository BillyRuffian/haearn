class AdminDashboardPolicy < ApplicationPolicy
  def index?
    user.admin?
  end
end
