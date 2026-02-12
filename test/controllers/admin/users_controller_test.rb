require 'test_helper'

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @user = users(:one)
  end

  test 'admin can list users' do
    sign_in_as(@admin)
    get admin_users_path
    assert_response :success
  end

  test 'admin can show a user' do
    sign_in_as(@admin)
    get admin_user_path(@user)
    assert_response :success
  end

  test 'admin can edit a user' do
    sign_in_as(@admin)
    get edit_admin_user_path(@user)
    assert_response :success
  end

  test 'admin can update a user' do
    sign_in_as(@admin)
    patch admin_user_path(@user), params: { user: { name: 'Updated Name' } }
    assert_redirected_to admin_user_path(@user)
    assert_equal 'Updated Name', @user.reload.name
  end

  test 'admin can toggle admin on another user' do
    sign_in_as(@admin)
    assert_not @user.admin?
    patch toggle_admin_admin_user_path(@user)
    assert_redirected_to admin_user_path(@user)
    assert @user.reload.admin?
  end

  test 'admin can deactivate a user' do
    sign_in_as(@admin)
    patch deactivate_admin_user_path(@user)
    assert_redirected_to admin_user_path(@user)
    assert @user.reload.deactivated?
  end

  test 'admin can reactivate a user' do
    @user.update!(deactivated_at: Time.current)
    sign_in_as(@admin)
    patch reactivate_admin_user_path(@user)
    assert_redirected_to admin_user_path(@user)
    assert @user.reload.active?
  end

  test 'admin can impersonate a user' do
    sign_in_as(@admin)
    post impersonate_admin_user_path(@user)
    assert_redirected_to root_path
  end

  test 'non-admin cannot access users' do
    sign_in_as(@user)
    get admin_users_path
    assert_redirected_to root_path
  end

  test 'actions create audit log entries' do
    sign_in_as(@admin)
    assert_difference 'AdminAuditLog.count' do
      patch deactivate_admin_user_path(@user)
    end
    log = AdminAuditLog.last
    assert_equal 'deactivate_user', log.action
    assert_equal @admin.id, log.admin_user_id
    assert_equal @user.id, log.target_user_id
  end

  test 'admin can search users' do
    sign_in_as(@admin)
    get admin_users_path, params: { search: 'Test User One' }
    assert_response :success
  end

  test 'admin can filter by status' do
    sign_in_as(@admin)
    get admin_users_path, params: { status: 'active' }
    assert_response :success
  end
end
