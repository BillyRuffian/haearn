require 'test_helper'

class Admin::AuditLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @user = users(:one)
  end

  test 'admin can view audit logs' do
    sign_in_as(@admin)
    get admin_audit_logs_path
    assert_response :success
  end

  test 'admin can filter audit logs by action' do
    sign_in_as(@admin)
    get admin_audit_logs_path, params: { action_filter: 'deactivate_user' }
    assert_response :success
  end

  test 'non-admin cannot access audit logs' do
    sign_in_as(@user)
    get admin_audit_logs_path
    assert_redirected_to root_path
  end
end
