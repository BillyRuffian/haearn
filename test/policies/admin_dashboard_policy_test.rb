require 'test_helper'

class AdminDashboardPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @user = users(:one)
  end

  test 'admin can access dashboard' do
    assert AdminDashboardPolicy.new(@admin, :admin_dashboard).index?
  end

  test 'regular user cannot access dashboard' do
    assert_not AdminDashboardPolicy.new(@user, :admin_dashboard).index?
  end
end
