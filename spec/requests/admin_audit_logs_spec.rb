require 'rails_helper'
require 'nokogiri'

RSpec.describe 'Admin audit logs', type: :request do
  it 'blocks non-admin users from admin audit logs' do
    sign_in_as(users(:one))

    get admin_audit_logs_path

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include('not authorized')
  end

  it 'shows audit logs to admins and supports action filtering' do
    admin = users(:admin)
    target = users(:one)
    sign_in_as(admin)

    AdminAuditLog.create!(
      admin_user: admin,
      target_user: target,
      action: 'reactivate_user',
      ip_address: '127.0.0.1'
    )

    get admin_audit_logs_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Audit Log')
    expect(response.body).to include('deactivate_user')
    expect(response.body).to include('reactivate_user')

    get admin_audit_logs_path, params: { action_filter: 'reactivate_user' }
    expect(response).to have_http_status(:ok)
    parsed = Nokogiri::HTML(response.body)
    actions = parsed.css('tbody td .badge').map { |node| node.text.strip.downcase }
    expect(actions).to include('reactivate user')
    expect(actions).not_to include('deactivate user')
  end
end
