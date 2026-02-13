require 'test_helper'

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test 'should get dashboard index when authenticated' do
    sign_in_as(@user)

    get root_path
    assert_response :success
    assert_select 'h1', text: /#{@user.name}/
  end

  test 'should get analytics page when authenticated' do
    sign_in_as(@user)

    get analytics_path
    assert_response :success
    assert_select 'h1', text: /Analytics/
  end

  test 'analytics should require authentication' do
    get analytics_path
    assert_redirected_to new_session_path
  end
end
