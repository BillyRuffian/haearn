require 'test_helper'

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @user = users(:one)
  end

  test 'admin can access dashboard' do
    sign_in_as(@admin)
    get admin_root_path
    assert_response :success
  end

  test 'non-admin is redirected from dashboard' do
    sign_in_as(@user)
    get admin_root_path
    assert_redirected_to root_path
  end

  test 'unauthenticated user is redirected to login' do
    get admin_root_path
    assert_redirected_to new_session_path
  end
end
