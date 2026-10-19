class AdminDashboardPolicy < ApplicationPolicy
  def index?
    user.admin?
  end

  def update_registration?
    user.admin?
  end
end
